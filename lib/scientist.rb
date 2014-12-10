# Include this module into any class which requires science experiments in its
# methods. Provides the `science` and `default_scientist_context` methods for
# defining and running experiments.
#
# If you need to run science on class methods, extend this module instead.
module Scientist
  # Define and run a science experiment.
  #
  # name - a String name for this experiment.
  # run: - optional argument for which named test to run instead of "control".
  #
  # Yields an object which implements the Scientist::Experiment interface.
  # See `Scientist::Experiment.new` for how this is defined.
  #
  # Returns the calculated value of the control experiment, or raises if an
  # exception was raised.
  def science(name, run = nil)
    experiment = Experiment.new(name)
    experiment.context(default_scientist_context)

    yield experiment

    experiment.run(run)
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
