# The immutable result of running an experiment.
class Scientist::Result

  # An Experiment.
  attr_reader :experiment

  # An Array of Observations in execution order.
  attr_reader :observations

  # The primary Observation
  attr_reader :primary

  # An Array of observations which didn't match the primary
  attr_reader :mismatched

  # Internal: Create a new result.
  def initialize(experiment, observations:, primary:)
    @experiment   = experiment
    @observations = observations
    @primary      = primary
    @mismatched   = evaluate_observations_for_mismatches

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

  # Internal: evaluate the observations to determine if the observations match.
  def evaluate_observations_for_mismatches
    observations.reject do |observation|
      observation == primary ||
        experiment.observations_are_equivalent?(primary, observation)
    end
  end
end
