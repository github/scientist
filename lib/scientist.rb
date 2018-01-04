# Include this module into any class which requires science experiments in its
# methods. Provides the `science` and `default_scientist_context` methods for
# defining and running experiments.
#
# If you need to run science on class methods, extend this module instead.
#
# If including or extending this module are not an option, call
# `Scientist.run`.
module Scientist
  # Define and run a science experiment.
  #
  # name - a String name for this experiment.
  # opts - optional hash with the the named test to run instead of "control",
  #        :run is the only valid key.
  #
  # Yields an object which implements the Scientist::Experiment interface.
  # See `Scientist::Experiment.new` for how this is defined.
  #
  # Returns the calculated value of the control experiment, or raises if an
  # exception was raised.
  def self.run(name, opts = {})
    experiment = Experiment.new(name)

    yield experiment

    test = opts[:run] if opts
    experiment.run(test)
  end

  # Define and run a science experiment.
  #
  # name - a String name for this experiment.
  # opts - optional hash with the the named test to run instead of "control",
  #        :run is the only valid key.
  #
  # Yields an object which implements the Scientist::Experiment interface.
  # See `Scientist::Experiment.new` for how this is defined. The context from
  # the `default_scientist_context` method will be applied to the experiment.
  #
  # Returns the calculated value of the control experiment, or raises if an
  # exception was raised.
  def science(name, opts = {})
    Scientist.run(name, opts) do |experiment|
      experiment.context(default_scientist_context)

      yield experiment
    end
  end

  # Public: the default context data for an experiment created and run via the
  # `science` helper method. Override this in any class that includes Scientist
  # to define your own behavior.
  #
  # Returns a Hash.
  def default_scientist_context
    {}
  end
end

require "scientist/default"
require "scientist/errors"
require "scientist/experiment"
require "scientist/observation"
require "scientist/result"
require "scientist/version"
