# The immutable result of running an experiment.
class Scientist::Result

  # An Experiment.
  attr_reader :experiment

  # An Array of observations which didn't match the primary, but were ignored
  attr_reader :ignored

  # An Array of observations which didn't match the primary
  attr_reader :mismatched

  # An Array of Observations in execution order.
  attr_reader :observations

  # The primary Observation
  attr_reader :primary

  # The experiment's context
  def context
    experiment.context
  end

  # Internal: Create a new result.
  def initialize(experiment, observations:, primary:)
    @experiment   = experiment
    @observations = observations
    @primary      = primary
    evaluate_observations

    freeze
  end

  # Public: was the result a match between all behaviors?
  def match?
    mismatched.empty?
  end

  # Public: were there mismatches in the behaviors?
  def mismatch?
    mismatched.any?
  end

  # Public: were there any ignored mismatches?
  def ignored?
    ignored.any?
  end

  # Internal: evaluate the observations to find mismatched and ignored results
  #
  # Sets @ignored and @mismatched with the ignored and mismatched observations.
  def evaluate_observations
    mismatched = observations.reject do |observation|
      observation == primary ||
        experiment.observations_are_equivalent?(primary, observation)
    end

    @ignored = mismatched.select do |observation|
      experiment.ignore_mismatched_observation? primary, observation
    end

    @mismatched = mismatched - @ignored
  end
end
