# Scientist!

A Ruby library for carefully refactoring critical paths.

## How do I do science?

Let's pretend you're changing the way you handle permissions in a large web app. Tests can help guide your refactoring, but you really want to compare the current and refactored behaviors under load.

```ruby
require "scientist"

class MyWidget
  def allows?(user)
    experiment = Scientist::Default.new "widget-permissions" do |e|
      e.use { model.check_user?(user).valid? } # old way
      e.try { user.can?(:read, model) } # new way
    end

    experiment.run
  end
end
```

Wrap a `use` block around the code's original behavior, and wrap `try` around the new behavior. `experiment.run` will always return whatever the `use` block returns, but it does a bunch of stuff behind the scenes:

* It decides whether or not to run the `try` block,
* Randomizes the order in which `use` and `try` blocks are run,
* Measures the durations of all behaviors,
* Compares the result of `try` to the result of `use`,
* Swallows (but records) any exceptions raise in the `try` block, and
* Publishes all this information.

The `try` block is called the **candidate**. The `use` block is called the **control**.

Creating an experiment is wordy, so the `Scientist#science` helper instantiates an experiment and calls `run`:

```ruby
require "scientist"

class MyWidget
  include Scientist

  def allows?(user)
    science "widget-permissions" do |e|
      e.use { model.check_user(user).valid? } # old way
      e.try { user.can?(:read, model) } # new way
    end
  end
end
```

## Making science useful

The examples above will run, but they're not really *doing* anything. The `try` blocks run every time and none of the results get published. Replace the default experiment implementation to control execution and reporting:

```ruby
require "scientist"

class MyExperiment < ActiveRecord::Base
  include Scientist::Experiment

  def enabled?
    # see "Ramping up experiments" below
    super
  end

  def publish(payload)
    # see "Publishing results" below
    super
  end
end

# replace `Scientist::Default`
def Scientist::Experiment.new(name)
  MyExperiment.find_or_initialize_by(name: name)
end
```

Now calls to the `science` helper will load instances of `MyExperiment`.

### Ramping up experiments

*TODO*


### Controlling comparison

Scientist compares control and candidate values using `==`. To override this behavior, use `compare` to define how to compare observed values instead:

```ruby
class MyWidget
  include Scientist

  def users
    science "users" do |e|
      e.use { User.all }         # returns User instances
      e.try { UserService.list } # returns UserService::User instances

      e.compare do |control, candidate|
        control.map(&:login) == candidate.map(&:login)
      end
    end
  end
end
```

### Adding context

Results aren't very useful without some way to identify them.

```ruby
science "widget-permissions" do |e|
  e.context :user => user

  e.use { model.check_user(user).valid? }
  e.try { user.can?(:read, model) }
end
```

`context` takes a Symbol-keyed Hash of extra data. The data is available in `publish` via `result.experiment.context`. If you're using the `science` helper a lot in a class, you can provide a default context:

```ruby
class MyWidget
  include Scientist

  def allows?(user)
    science "widget-permissions" do |e|
      e.context :user => user

      e.use { model.check_user(user).valid? }
      e.try { user.can?(:read, model) }
    end
  end

  def destroy
    science "widget-destruction" do |e|
      e.use { old_scary_destroy }
      e.try { new_safe_destroy }
    end
  end

  def default_scientist_context
    { :widget => self }
  end
end
```

The `widget-permissions` and `widget-destruction` experiments will both have a `:widget` key in their contexts.

### Keeping it clean

Sometimes you don't want to store the full value for later analysis. For example, an experiment may return `User` instances, but when researching a mismatch, all you care about is the logins. You can define how to clean these values in an experiment:

```ruby
class MyWidget
  include Scientist

  def users
    science "users" do |e|
      e.use { User.all }
      e.try { UserService.list }

      e.clean do |value|
        value.map(&:login).sort
      end
    end
  end
end
```

And this cleaned value is available in observations in the final published result:

```ruby
class MyExperiment < ActiveRecord::Base
  include Scientist::Experiment

  def publish(result)
    result.control.value         # [<User alice>, <User bob>, <User carol>]
    result.control.cleaned_value # ["alice", "bob", "carol"]
  end
end
```

### Ignoring mismatches

During the early stages of an experiment, it's possible that some of your code will always generate a mismatch for reasons you know and understand but haven't yet fixed. Instead of these known cases always showing up as mismatches in your metrics or analysis, you can tell an experiment whether or not to ignore a mismatch using the `ignore` method. You may include more than one block if needed:

```ruby
def admin?(user)
  science "widget-permissions" do |e|
    e.use { model.check_user(user).admin? }
    e.try { user.can?(:admin, model) }

    e.ignore { user.staff? } # user is staff, always an admin in the new system
    e.ignore do |control, candidate|
      # new system doesn't handle unconfirmed users yet:
      control && !candidate && !user.confirmed_email?
    end
  end
end
```

The ignore blocks are only called if the *values* don't match. If one observation raises an exception and the other doesn't, it's always considered a mismatch.

### Publishing results

What good is science if you can't publish your results?

You must implement the `publish(result)` method, and can publish data however you like. For example, timing data can be sent to graphite, and mismatches can be placed in a capped collection in redis for debugging later.

The `publish` method is given a `Scientist::Result` instance with its associated `Scientist::Observation`s:

```ruby
class MyExperiment
  include Scientist::Experiment

  # ...

  def publish(result)

    # Store the timing for the control value,
    $statsd.timing "science.#{name}.control", result.primary.duration
    # for the candidate (only the first, see "Breaking the rules" below,
    $statsd.timing "science.#{name}.candidate", result.candidates.first.duration

    # and counts for match/ignore/mismatch:
    if result.matched?
      $statsd.increment "science.#{name}.matched"
    elsif result.ignored?
      $statsd.increment "science.#{name}.ignored"
    else
      $statsd.increment "science.#{name}.mismatched"
      # Finally, store mismatches in redis so they can be retrieved and examined
      # later on, for debugging and research.
      store_mismatch_data(result)
    end
  end

  def store_mismatch_data(result)
    payload = {
      :name            => name,
      :context         => context,
      :control         => observation_payload(result.control),
      :candidate       => observation_payload(result.candidates.first)
      :execution_order => result.observations.map(&:name),
    }

    key = "science.#{name}.mismatch"
    $redis.lpush key, payload
    $redis.ltrim key, 0, 1000
  end

  def observation_payload(observation)
    if observation.raised?
      {
        :exception => observation.exeception.class,
        :message   => observation.exeception.message,
        :backtrace => observation.exception.backtrace
      }
    else
      {
        # see "Keeping it clean" below
        :value => observation.cleaned_value
      }
    end
  end
end
```


## Breaking the rules

Sometimes scientists just gotta do weird stuff. We understand.

### Trying more than one thing

It's not usually a good idea to try more than one alternative simultaneously. Behavior isn't guaranteed to be isolated and reporting + visualization get quite a bit harder. Still, it's sometimes useful.

To try more than one alternative at once, add names to some `try` blocks:

```ruby
require "scientist"

class MyWidget
  include Scientist

  def allows?(user)
    science "widget-permissions" do |e|
      e.use { model.check_user(user).valid? } # old way

      e.try("api") { user.can?(:read, model) } # new service API
      e.try("raw-sql") { user.can_sql?(:read, model) } # raw query
    end
  end
end
```

### No control, just candidates

Define the candidates with named `try` blocks, omit a `use`, and pass a candidate name to `run`:

```ruby
experiment = MyExperiment.new("various-ways") do |e|
  e.try("first-way")  { ... }
  e.try("second-way") { ... }
end

experiment.run("second-way")
```

The `science` helper also knows this trick:

```ruby
science "various-ways", run: "first-way" do |e|
  e.try("first-way")  { ... }
  e.try("second-way") { ... }
end
```

## Hacking

Be on a Unixy box. Make sure a modern Bundler is available. `script/test` runs the unit tests. All development dependencies are  installed automatically. Science requires Ruby 2.1.

## Maintainers

[@jbarnette](https://github.com/jbarnette),
[@jesseplusplus](https://github.com/jesseplusplus),
[@rick](https://github.com/rick),
and [@zerowidth](https://github.com/zerowidth)
