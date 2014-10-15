# This mixin provides shared behavior for experiments. Includers must implement
# `enabled?` and `publish(result)`.
module Scientist::Experiment

  # Internal: the configured implementation for science experiments.
  # Defaults to Scientist::Default
  def self.implementation
    @implementation_class ||= Scientist::Default
  end

  # Set the implementation class for experiments. This class must implement the
  # Scientist::Experiment interface.
  def self.implementation=(implementation_class)
    @implementation_class = implementation_class
  end

  # Create a new instance of a class that implements the Scientist::Experiment
  # interface. Set `Scientist::Experiment.implementation` to change.
  def self.new(name)
    implementation.new(name)
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
  def clean_value(value)
    if @_scientist_cleaner
      @_scientist_cleaner.call value
    else
      value
    end
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
  # The block takes two arguments, the control and the candidate observation
  # which didn't match the control. If the block returns true, the mismatch is
  # disregarded.
  #
  # This can be called more than once with different blocks to use.
  def ignore(&block)
    @_scientist_ignores ||= []
    @_scientist_ignores << block
  end

  # Internal: ignore a mismatched observation?
  #
  # Iterates through the configured ignore blocks and calls each of them with
  # the given primary and mismatched candidate observations.
  #
  # Returns true or false.
  def ignore_mismatched_observation?(primary, candidate)
    return false unless @_scientist_ignores
    @_scientist_ignores.any? do |ignore|
      begin
        ignore.call primary, candidate
      rescue StandardError => ex
        raised(:ignore, ex)
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
    raised(:compare, ex)
    false
  end

  # Called when an exception is raised while running an internal operation,
  # like :publish. Override this method to track these exceptions. The
  # default implementation re-raises the exception.
  def raised(operation, error)
    raise error
  end

  # Run all the behaviors for this experiment, observing each and publishing
  # the results. Return the result of the named behavior, default "control".
  def run(name = nil)
    behaviors.freeze
    context.freeze

    name = (name || "control").to_s
    block = behaviors[name]

    if block.nil?
      raise Scientist::BehaviorMissing.new(self, name)
    end

    if behaviors.size == 1 || !enabled?
      return block.call
    end

    observations = []

    behaviors.keys.shuffle.each do |key|
      block = behaviors[key]
      observations << Scientist::Observation.new(key, self, &block)
    end

    primary = observations.detect { |o| o.name == name }

    result = Scientist::Result.new self,
      observations: observations,
      primary: primary

    begin
      publish(result)
    rescue StandardError => ex
      raised(:publish, ex)
    end

    if primary.raised?
      raise primary.exception
    end

    primary.value
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
