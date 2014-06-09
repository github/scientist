# The immutable result of running an experiment.
class Scientist::Result

  # An Experiment.
  attr_reader :experiment

  # An Array of Observations in execution order.
  attr_reader :observations

  # The String name of the primary observed behavior.
  attr_reader :primary

  def initialize(experiment, observations, primary)
    @experiment = experiment
    @observations = observations
    @primary = primary

    freeze
  end
end
