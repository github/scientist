# Scientist!

A Ruby library for carefully refactoring critical paths. [![Build Status](https://travis-ci.org/github/scientist.svg?branch=master)](https://travis-ci.org/github/scientist) [![Coverage Status](https://coveralls.io/repos/github/github/scientist/badge.svg?branch=master)](https://coveralls.io/github/github/scientist?branch=master)

## How do I science?

Let's pretend you're changing the way you handle permissions in a large web app. Tests can help guide your refactoring, but you really want to compare the current and refactored behaviors under load.

```ruby
require "scientist"

class MyWidget
  def allows?(user)
    experiment = Scientist::Default.new "widget-permissions"
    experiment.use { model.check_user?(user).valid? } # old way
    experiment.try { user.can?(:read, model) } # new way

    experiment.run
  end
end
```

Wrap a `use` block around the code's original behavior, and wrap `try` around the new behavior. `experiment.run` will always return whatever the `use` block returns, but it does a bunch of stuff behind the scenes:

* It decides whether or not to run the `try` block,
* Randomizes the order in which `use` and `try` blocks are run,
* Measures the durations of all behaviors in seconds,
* Compares the result of `try` to the result of `use`,
* Swallow and record exceptions raised in the `try` block when overriding `raised`, and
* Publishes all this information.

The `use` block is called the **control**. The `try` block is called the **candidate**.

Creating an experiment is wordy, but when you include the `Scientist` module, the `science` helper will instantiate an experiment and call `run` for you:

```ruby
require "scientist"

class MyWidget
  include Scientist

  def allows?(user)
    science "widget-permissions" do |experiment|
      experiment.use { model.check_user(user).valid? } # old way
      experiment.try { user.can?(:read, model) } # new way
    end # returns the control value
  end
end
```

If you don't declare any `try` blocks, none of the Scientist machinery is invoked and the control value is always returned.

## Making science useful

The examples above will run, but they're not really *doing* anything. The `try` blocks don't run yet and none of the results get published. Replace the default experiment implementation to control execution and reporting:

```ruby
require "scientist/experiment"

class MyExperiment
  include Scientist::Experiment

  attr_accessor :name

  def initialize(name)
    @name = name
  end

  def enabled?
    # see "Ramping up experiments" below
    true
  end

  def raised(operation, error)
    # see "In a Scientist callback" below
    p "Operation '#{operation}' failed with error '#{error.inspect}'"
    super # will re-raise
  end

  def publish(result)
    # see "Publishing results" below
    p result
  end
end
```

When `Scientist::Experiment` is included in a class, it automatically sets it as the default implementation via `Scientist::Experiment.set_default`. This `set_default` call is is skipped if you include `Scientist::Experiment` in a module.

Now calls to the `science` helper will load instances of `MyExperiment`.

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

Results aren't very useful without some way to identify them. Use the `context` method to add to or retrieve the context for an experiment:

```ruby
science "widget-permissions" do |e|
  e.context :user => user

  e.use { model.check_user(user).valid? }
  e.try { user.can?(:read, model) }
end
```

`context` takes a Symbol-keyed Hash of extra data. The data is available in `Experiment#publish` via the `context` method. If you're using the `science` helper a lot in a class, you can provide a default context:

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

### Expensive setup

If an experiment requires expensive setup that should only occur when the experiment is going to be run, define it with the `before_run` method:

```ruby
# Code under test modifies this in-place. We want to copy it for the
# candidate code, but only when needed:
value_for_original_code = big_object
value_for_new_code      = nil

science "expensive-but-worthwhile" do |e|
  e.before_run do
    value_for_new_code = big_object.deep_copy
  end
  e.use { original_code(value_for_original_code) }
  e.try { new_code(value_for_new_code) }
end
```

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
class MyExperiment
  include Scientist::Experiment

  # ...

  def publish(result)
    result.control.value         # [<User alice>, <User bob>, <User carol>]
    result.control.cleaned_value # ["alice", "bob", "carol"]
  end
end
```

Note that the `#clean` method will discard the previous cleaner block if you call it again.  If for some reason you need to access the currently configured cleaner block, `Scientist::Experiment#cleaner` will return the block without further ado.  _(This probably won't come up in normal usage, but comes in handy if you're writing, say, a custom experiment runner that provides default cleaners.)_

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

The ignore blocks are only called if the *values* don't match. If one observation raises an exception and the other doesn't, it's always considered a mismatch. If both observations raise different exceptions, that is also considered a mismatch.

### Enabling/disabling experiments

Sometimes you don't want an experiment to run. Say, disabling a new codepath for anyone who isn't staff. You can disable an experiment by setting a `run_if` block. If this returns `false`, the experiment will merely return the control value. Otherwise, it defers to the experiment's configured `enabled?` method.

```ruby
class DashboardController
  include Scientist

  def dashboard_items
    science "dashboard-items" do |e|
      # only run this experiment for staff members
      e.run_if { current_user.staff? }
      # ...
  end
end
```

### Ramping up experiments

As a scientist, you know it's always important to be able to turn your experiment off, lest it run amok and result in villagers with pitchforks on your doorstep. In order to control whether or not an experiment is enabled, you must include the `enabled?` method in your `Scientist::Experiment` implementation.

```ruby
class MyExperiment
  include Scientist::Experiment

  attr_accessor :name, :percent_enabled

  def initialize(name)
    @name = name
    @percent_enabled = 100
  end

  def enabled?
    percent_enabled > 0 && rand(100) < percent_enabled
  end

  # ...

end
```

This code will be invoked for every method with an experiment every time, so be sensitive about its performance. For example, you can store an experiment in the database but wrap it in various levels of caching such as memcache or per-request thread-locals.

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
    $statsd.timing "science.#{name}.control", result.control.duration
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
      :candidate       => observation_payload(result.candidates.first),
      :execution_order => result.observations.map(&:name)
    }

    key = "science.#{name}.mismatch"
    $redis.lpush key, payload
    $redis.ltrim key, 0, 1000
  end

  def observation_payload(observation)
    if observation.raised?
      {
        :exception => observation.exception.class,
        :message   => observation.exception.message,
        :backtrace => observation.exception.backtrace
      }
    else
      {
        # see "Keeping it clean" above
        :value => observation.cleaned_value
      }
    end
  end
end
```

### Testing

When running your test suite, it's helpful to know that the experimental results always match. To help with testing, Scientist defines a `raise_on_mismatches` class attribute when you include `Scientist::Experiment`. Only do this in your test suite!

To raise on mismatches:

```ruby
class MyExperiment
  include Scientist::Experiment
  # ... implementation
end

MyExperiment.raise_on_mismatches = true
```

Scientist will raise a `Scientist::Experiment::MismatchError` exception if any observations don't match.

#### Custom mismatch errors

To instruct Scientist to raise a custom error instead of the default `Scientist::Experiment::MismatchError`:

```ruby
class CustomMismatchError < Scientist::Experiment::MismatchError
  def to_s
    message = "There was a mismatch! Here's the diff:"

    diffs = result.candidates.map do |candidate|
      Diff.new(result.control, candidate)
    end.join("\n")

    "#{message}\n#{diffs}"
  end
end
```

```ruby
science "widget-permissions" do |e|
  e.use { Report.find(id) }
  e.try { ReportService.new.fetch(id) }

  e.raise_with CustomMismatchError
end
```

This allows for pre-processing on mismatch error exception messages.

### Handling errors

#### In candidate code

Scientist rescues and tracks _all_ exceptions raised in a `try` or `use` block, including some where rescuing may cause unexpected behavior (like `SystemExit` or `ScriptError`). To rescue a more restrictive set of exceptions, modify the `RESCUES` list:

```ruby
# default is [Exception]
Scientist::Observation::RESCUES.replace [StandardError]
```

#### In a Scientist callback

If an exception is raised within any of Scientist's internal helpers, like `publish`, `compare`, or `clean`, the `raised` method is called with the symbol name of the internal operation that failed and the exception that was raised. The default behavior of `Scientist::Default` is to simply re-raise the exception. Since this halts the experiment entirely, it's often a better idea to handle this error and continue so the experiment as a whole isn't canceled entirely:

```ruby
class MyExperiment
  include Scientist::Experiment

  # ...

  def raised(operation, error)
    InternalErrorTracker.track! "science failure in #{name}: #{operation}", error
  end
end
```

The operations that may be handled here are:

* `:clean` - an exception is raised in a `clean` block
* `:compare` - an exception is raised in a `compare` block
* `:enabled` - an exception is raised in the `enabled?` method
* `:ignore` - an exception is raised in an `ignore` block
* `:publish` - an exception is raised in the `publish` method
* `:run_if` - an exception is raised in a `run_if` block

### Designing an experiment

Because `enabled?` and `run_if` determine when a candidate runs, it's impossible to guarantee that it will run every time. For this reason, Scientist is only safe for wrapping methods that aren't changing data.

When using Scientist, we've found it most useful to modify both the existing and new systems simultaneously anywhere writes happen, and verify the results at read time with `science`. `raise_on_mismatches` has also been useful to ensure that the correct data was written during tests, and reviewing published mismatches has helped us find any situations we overlooked with our production data at runtime. When writing to and reading from two systems, it's also useful to write some data reconciliation scripts to verify and clean up production data alongside any running experiments.

#### Noise and error rates

Keep in mind that Scientist's `try` and `use` blocks run sequentially in random order. As such, any data upon which your code depends may change before the second block is invoked, potentially yielding a mismatch between the candidate and control return values. To calibrate your expectations with respect to [false negatives](https://en.wikipedia.org/wiki/Type_I_and_type_II_errors) arising from systemic conditions external to your proposed changes, consider starting with an experiment in which both the `try` and `use` blocks invoke the control method. Then proceed with introducing a candidate.

### Finishing an experiment

As your candidate behavior converges on the controls, you'll start thinking about removing an experiment and using the new behavior.

* If there are any ignore blocks, the candidate behavior is *guaranteed* to be different. If this is unacceptable, you'll need to remove the ignore blocks and resolve any ongoing mismatches in behavior until the observations match perfectly every time.
* When removing a read-behavior experiment, it's a good idea to keep any write-side duplication between an old and new system in place until well after the new behavior has been in production, in case you need to roll back.

## Breaking the rules

Sometimes scientists just gotta do weird stuff. We understand.

### Ignoring results entirely

Science is useful even when all you care about is the timing data or even whether or not a new code path blew up. If you have the ability to incrementally control how often an experiment runs via your `enabled?` method, you can use it to silently and carefully test new code paths and ignore the results altogether. You can do this by setting `ignore { true }`, or for greater efficiency, `compare { true }`.

This will still log mismatches if any exceptions are raised, but will disregard the values entirely.

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

When the experiment runs, all candidate behaviors are tested and each candidate observation is compared with the control in turn.

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

#### Providing fake timing data

If you're writing tests that depend on specific timing values, you can provide canned durations using the `fabricate_durations_for_testing_purposes` method, and Scientist will report these in `Scientist::Observation#duration` instead of the actual execution times.

```ruby
science "absolutely-nothing-suspicious-happening-here" do |e|
  e.use { ... } # "control"
  e.try { ... } # "candidate"
  e.fabricate_durations_for_testing_purposes( "control" => 1.0, "candidate" => 0.5 )
end
```

`fabricate_durations_for_testing_purposes` takes a Hash of duration values, keyed by behavior names.  (By default, Scientist uses `"control"` and `"candidate"`, but if you override these as shown in [Trying more than one thing](#trying-more-than-one-thing) or [No control, just candidates](#no-control-just-candidates), use matching names here.)  If a name is not provided, the actual execution time will be reported instead.

_Like `Scientist::Experiment#cleaner`, this probably won't come up in normal usage.  It's here to make it easier to test code that extends Scientist._

### Without including Scientist

If you need to use Scientist in a place where you aren't able to include the Scientist module, you can call `Scientist.run`:

```ruby
Scientist.run "widget-permissions" do |e|
  e.use { model.check_user(user).valid? }
  e.try { user.can?(:read, model) }
end
```

## Hacking

Be on a Unixy box. Make sure a modern Bundler is available. `script/test` runs the unit tests. All development dependencies are installed automatically. Scientist requires Ruby 2.3 or newer.

## Wrappers

- [RealGeeks/lab_tech](https://github.com/RealGeeks/lab_tech) is a Rails engine for using this library by controlling, storing, and analyzing experiment results with ActiveRecord.

## Alternatives

- [daylerees/scientist](https://github.com/daylerees/scientist) (PHP)
- [scientistproject/scientist.net](https://github.com/scientistproject/Scientist.net) (.NET)
- [joealcorn/laboratory](https://github.com/joealcorn/laboratory) (Python)
- [rawls238/Scientist4J](https://github.com/rawls238/Scientist4J) (Java)
- [tomiaijo/scientist](https://github.com/tomiaijo/scientist) (C++)
- [trello/scientist](https://github.com/trello/scientist) (node.js)
- [ziyasal/scientist.js](https://github.com/ziyasal/scientist.js) (node.js, ES6)
- [TrueWill/tzientist](https://github.com/TrueWill/tzientist) (node.js, TypeScript)
- [TrueWill/paleontologist](https://github.com/TrueWill/paleontologist) (Deno, TypeScript)
- [yeller/laboratory](https://github.com/yeller/laboratory) (Clojure)
- [lancew/Scientist](https://github.com/lancew/Scientist) (Perl 5)
- [lancew/ScientistP6](https://github.com/lancew/ScientistP6) (Perl 6)
- [MadcapJake/Test-Lab](https://github.com/MadcapJake/Test-Lab) (Perl 6)
- [cwbriones/scientist](https://github.com/cwbriones/scientist) (Elixir)
- [calavera/go-scientist](https://github.com/calavera/go-scientist) (Go)
- [jelmersnoeck/experiment](https://github.com/jelmersnoeck/experiment) (Go)
- [spoptchev/scientist](https://github.com/spoptchev/scientist) (Kotlin / Java)
- [junkpiano/scientist](https://github.com/junkpiano/scientist) (Swift)
- [serverless scientist](http://serverlessscientist.com/) (AWS Lambda)
- [fightmegg/scientist](https://github.com/fightmegg/scientist) (TypeScript, Browser / Node.js)

## Maintainers

[@jbarnette](https://github.com/jbarnette),
[@jesseplusplus](https://github.com/jesseplusplus),
[@rick](https://github.com/rick),
and [@zerowidth](https://github.com/zerowidth)
