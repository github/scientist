# This mixin provides shared behavior for experiments. Includers must implement
# `enabled?` and `publish(result)`.
#
# Override Scientist::Experiment.new to set your own class which includes and
# implements Scientist::Experiment's interface.
module Scientist::Experiment

  # Create a new instance of a class that implements the Scientist::Experiment
  # interface.
  #
  # Override this method directly to change the default implementation.
  def self.new(name)
    Scientist::Default.new(name)
  end

  # A mismatch, raised when raise_on_mismatches is enabled.
  class MismatchError < StandardError
    def initialize(name, result)
      super "#{name}: control #{result.control.inspect}, candidates #{result.candidates.map(&:inspect)}"
    end
  end

  module RaiseOnMismatch
    # Set this flag to raise on experiment mismatches.
    #
    # This causes all science mismatches to raise a MismatchError. This is
    # intended for test environments and should not be enabled in a production
    # environment.
    #
    # bool - true/false - whether to raise when the control and candidate mismatch.
    def raise_on_mismatches=(bool)
      @raise_on_mismatches = bool
    end

    # Whether or not to raise a mismatch error when a mismatch occurs.
    def raise_on_mismatches?
      @raise_on_mismatches
    end
  end

  def self.included(base)
    base.extend RaiseOnMismatch
  end

  # A Hash of behavior blocks, keyed by String name. Register behavior blocks
  # with the `try` and `use` methods.
  def behaviors
    @_scientist_behaviors ||= {}
  end

  # A block to clean an observed value for publishing or storing.
  #
  # The block takes one argument, the observed value which will be cleaned.
  #
  # Returns the configured block.
  def clean(&block)
    @_scientist_cleaner = block
  end

  # Internal: Clean a value with the configured clean block, or return the value
  # if no clean block is configured.
  #
  # Rescues and reports exceptions in the clean block if they occur.
  def clean_value(value)
    if @_scientist_cleaner
      @_scientist_cleaner.call value
    else
      value
    end
  rescue StandardError => ex
    raised :clean, ex
    value
  end

  # A block which compares two experimental values.
  #
  # The block must take two arguments, the control value and a candidate value,
  # and return true or false.
  #
  # Returns the block.
  def compare(*args, &block)
    @_scientist_comparator = block
  end

  # A Symbol-keyed Hash of extra experiment data.
  def context(context = nil)
    @_scientist_context ||= {}
    @_scientist_context.merge!(context) if !context.nil?
    @_scientist_context
  end

  # Configure this experiment to ignore an observation with the given block.
  #
  # The block takes two arguments, the control observation and the candidate
  # observation which didn't match the control. If the block returns true, the
  # mismatch is disregarded.
  #
  # This can be called more than once with different blocks to use.
  def ignore(&block)
    @_scientist_ignores ||= []
    @_scientist_ignores << block
  end

  # Internal: ignore a mismatched observation?
  #
  # Iterates through the configured ignore blocks and calls each of them with
  # the given control and mismatched candidate observations.
  #
  # Returns true or false.
  def ignore_mismatched_observation?(control, candidate)
    return false unless @_scientist_ignores
    @_scientist_ignores.any? do |ignore|
      begin
        ignore.call control.value, candidate.value
      rescue StandardError => ex
        raised :ignore, ex
        false
      end
    end
  end

  # The String name of this experiment. Default is "experiment". See
  # Scientist::Default for an example of how to override this default.
  def name
    "experiment"
  end

  # Internal: compare two observations, using the configured compare block if present.
  def observations_are_equivalent?(a, b)
    if @_scientist_comparator
      a.equivalent_to?(b, &@_scientist_comparator)
    else
      a.equivalent_to? b
    end
  rescue StandardError => ex
    raised :compare, ex
    false
  end

  # Called when an exception is raised while running an internal operation,
  # like :publish. Override this method to track these exceptions. The
  # default implementation re-raises the exception.
  def raised(operation, error)
    raise error
  end

  # Internal: Run all the behaviors for this experiment, observing each and
  # publishing the results. Return the result of the named behavior, default
  # "control".
  def run(name = nil)
    behaviors.freeze
    context.freeze

    name = (name || "control").to_s
    block = behaviors[name]

    if block.nil?
      raise Scientist::BehaviorMissing.new(self, name)
    end

    return block.call unless should_experiment_run?

    observations = []

    behaviors.keys.shuffle.each do |key|
      block = behaviors[key]
      observations << Scientist::Observation.new(key, self, &block)
    end

    control = observations.detect { |o| o.name == name }

    result = Scientist::Result.new self, observations, control

    begin
      publish(result)
    rescue StandardError => ex
      raised :publish, ex
    end

    if control.raised?
      raise control.exception
    end

    if self.class.raise_on_mismatches?
      if raised = observations.detect { |o| o.raised? }
        raise raised.exception
      elsif result.mismatched?
        raise MismatchError.new(name, result)
      end
    end

    control.value
  end

  # Define a block that determines whether or not the experiment should run.
  def run_if(&block)
    @_scientist_run_if_block = block
  end

  # Internal: does a run_if block allow the experiment to run?
  #
  # Rescues and reports exceptions in a run_if block if they occur.
  def run_if_block_allows?
    (@_scientist_run_if_block ? @_scientist_run_if_block.call : true)
  rescue StandardError => ex
    raised :run_if, ex
    return false
  end

  # Internal: determine whether or not an experiment should run.
  #
  # Rescues and reports exceptions in the enabled method if they occur.
  def should_experiment_run?
    behaviors.size > 1 && enabled? && run_if_block_allows?
  rescue StandardError => ex
    raised :enabled, ex
    return false
  end

  # Register a named behavior for this experiment, default "candidate".
  def try(name = nil, &block)
    name = (name || "candidate").to_s

    if behaviors.include?(name)
      raise Scientist::BehaviorNotUnique.new(self, name)
    end

    behaviors[name] = block
  end

  # Register the control behavior for this experiment.
  def use(&block)
    try "control", &block
  end
end
