# The immutable result of running an experiment.
class Scientist::Result

  # An Array of candidate Observations.
  attr_reader :candidates

  # The control Observation to which the rest are compared.
  attr_reader :control

  # An Experiment.
  attr_reader :experiment

  # An Array of observations which didn't match the control, but were ignored.
  attr_reader :ignored

  # An Array of observations which didn't match the control.
  attr_reader :mismatched

  # An Array of Observations in execution order.
  attr_reader :observations

  # Internal: Create a new result.
  #
  # experiment    - the Experiment this result is for
  # observations: - an Array of Observations, in execution order
  # control:      - the control Observation
  #
  def initialize(experiment, observations = [], control = nil)
    @experiment   = experiment
    @observations = observations
    @control      = control
    @candidates   = observations - [control]
    evaluate_candidates

    freeze
  end

  # Public: the experiment's context
  def context
    experiment.context
  end

  # Public: the name of the experiment
  def experiment_name
    experiment.name
  end

  # Public: was the result a match between all behaviors?
  def matched?
    mismatched.empty? && !ignored?
  end

  # Public: were there mismatches in the behaviors?
  def mismatched?
    mismatched.any?
  end

  # Public: were there any ignored mismatches?
  def ignored?
    ignored.any?
  end

  # Internal: evaluate the candidates to find mismatched and ignored results
  #
  # Sets @ignored and @mismatched with the ignored and mismatched candidates.
  def evaluate_candidates
    mismatched = candidates.reject do |candidate|
      experiment.observations_are_equivalent?(control, candidate)
    end

    @ignored = mismatched.select do |candidate|
      experiment.ignore_mismatched_observation? control, candidate
    end

    @mismatched = mismatched - @ignored
  end
end
