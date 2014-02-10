# Scientist!

A Ruby library for carefully refactoring critical paths.

## How do I do science?

Let's pretend you're changing the way you handle permissions in a large web app. Tests can help guide your refactoring, but you really want to compare the current and refactored behaviors under load.

```ruby
require "scientist"

class MyApp::Widget
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

class MyApp::Widget
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

The examples above will run, but they're not really *doing* anything. The `try` blocks run every time and none of the results get published. Add an experiment class to control execution and reporting:

```ruby
require "scientist"

class MyApp::Experiment
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
Scientist.experiment = MyApp::Experiment
```

Now calls to the `science` helper will create instances of `MyApp::Experiment`.

### Ramping up experiments

*TODO*

### Publishing results

*TODO*

### Controlling comparison

*TODO*

### Skipping outliers

*TODO*

### Adding context

*TODO*

### Keeping it clean

*TODO*

## What do I do with all these results?

*TODO*

## Breaking the rules

Sometimes scientists just gotta do weird stuff. We understand.

### Trying more than one thing

It's not usually a good idea to try more than one alternative simultaneously. Behavior isn't guaranteed to be isolated and reporting + visualization get quite a bit harder. Still, it's sometimes useful.

To try more than one alternative at once, add names to some `try` blocks:

```ruby
require "scientist"

class MyApp::Widget
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
experiment = MyApp::Experiment.new("various-ways") do |e|
  e.try("first-way")  { ... }
  e.try("second-way") { ... }
end

experiment.run("second-way")
```

The `science` helper also knows this trick:

```ruby
science "various-ways", :use => "first-way" do |e|
  e.try("first-way")  { ... }
  e.try("second-way") { ... }
end
```

## Hacking

Be on a Unixy box. Make sure a modern Bundler is available. `script/test` runs the unit tests. All development dependencies will be installed automatically if they're not available. Science requires Ruby 2.1.0.

## Maintainers

[@jbarnette](https://github.com/jbarnette), [@rick](https://github.com/rick), and [@zerowidth](https://github.com/zerowidth)
