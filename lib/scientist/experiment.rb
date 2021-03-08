# This mixin provides shared behavior for experiments. Includers must implement
# `enabled?` and `publish(result)`.
#
# Override Scientist::Experiment.new to set your own class which includes and
# implements Scientist::Experiment's interface.
module Scientist::Experiment

  # Whether to raise when the control and candidate mismatch.
  # If this is nil, raise_on_mismatches class attribute is used instead.
  attr_accessor :raise_on_mismatches

  def self.included(base)
    self.set_default(base) if base.instance_of?(Class)
    base.extend RaiseOnMismatch
  end

  # Instantiate a new experiment (using the class given to the .set_default method).
  def self.new(name)
    (@experiment_klass || Scientist::Default).new(name)
  end

  # Configure Scientist to use the given class for all future experiments
  # (must implement the Scientist::Experiment interface).
  #
  # Called automatically when new experiments are defined.
  def self.set_default(klass)
    @experiment_klass = klass
  end

  # A mismatch, raised when raise_on_mismatches is enabled.
  class MismatchError < Exception
    attr_reader :name, :result

    def initialize(name, result)
      @name   = name
      @result = result
      super "experiment '#{name}' observations mismatched"
    end

    # The default formatting is nearly unreadable, so make it useful.
    #
    # The assumption here is that errors raised in a test environment are
    # printed out as strings, rather than using #inspect.
    def to_s
      super + ":\n" +
      format_observation(result.control) + "\n" +
      result.candidates.map { |candidate| format_observation(candidate) }.join("\n") +
      "\n"
    end

    def format_observation(observation)
      observation.name + ":\n" +
      if observation.raised?
        lines = observation.exception.backtrace.map { |line| "    #{line}" }.join("\n")
        "  #{observation.exception.inspect}" + "\n" + lines
      else
        "  #{observation.cleaned_value.inspect}"
      end
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

  # Define a block of code to run before an experiment begins, if the experiment
  # is enabled.
  #
  # The block takes no arguments.
  #
  # Returns the configured block.
  def before_run(&block)
    @_scientist_before_run = block
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

  # Accessor for the clean block, if one is available.
  #
  # Returns the configured block, or nil.
  def cleaner
    @_scientist_cleaner
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
    @_scientist_context.merge!(context) unless context.nil?
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

  def raise_with(exception)
    @_scientist_custom_mismatch_error = exception
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

    unless should_experiment_run?
      return block.call
    end

    if @_scientist_before_run
      @_scientist_before_run.call
    end

    result = generate_result(name)

    begin
      publish(result)
    rescue StandardError => ex
      raised :publish, ex
    end

    if raise_on_mismatches? && result.mismatched?
      if @_scientist_custom_mismatch_error
        raise @_scientist_custom_mismatch_error.new(self.name, result)
      else
        raise MismatchError.new(self.name, result)
      end
    end

    control = result.control
    raise control.exception if control.raised?
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

  # Whether or not to raise a mismatch error when a mismatch occurs.
  def raise_on_mismatches?
    if raise_on_mismatches.nil?
      self.class.raise_on_mismatches?
    else
      !!raise_on_mismatches
    end
  end

  # Provide predefined durations to use instead of actual timing data.
  # This is here solely as a convenience for developers of libraries that extend Scientist.
  def fabricate_durations_for_testing_purposes(fabricated_durations = {})
    @_scientist_fabricated_durations = fabricated_durations
  end

  # Internal: Generate the observations and create the result from those and the control.
  def generate_result(name)
    observations = []

    behaviors.keys.shuffle.each do |key|
      block = behaviors[key]
      fabricated_duration = @_scientist_fabricated_durations && @_scientist_fabricated_durations[key]
      observations << Scientist::Observation.new(key, self, fabricated_duration: fabricated_duration, &block)
    end

    control = observations.detect { |o| o.name == name }
    Scientist::Result.new(self, observations, control)
  end
end
