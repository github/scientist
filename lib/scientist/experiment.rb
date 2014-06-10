# This mixin provides shared behavior for experiments. Includers must implement
# `enabled?` and `publish(result)`.
module Scientist::Experiment

  # Create a new instance of a class that implements the Scientist::Experiment
  # interface. Override `Scientist::Experiment.implementation` to change.
  def self.new(name, **options)
    Scientist::Default.new(name)
  end

  # A Hash of behavior blocks, keyed by String name. Register behavior blocks
  # with the `try` and `use` methods.
  def behaviors
    @_scientist_behaviors ||= {}
  end

  # A Symbol-keyed Hash of extra experiment data.
  def context(context = nil)
    @_scientist_context ||= {}
    @_scientist_context.merge!(context) if !context.nil?
    @_scientist_context
  end

  # The String name of this experiment. Default is "experiment". See
  # Scientist::Default for an example of how to override this default.
  def name
    "experiment"
  end

  # Called when an exception is raised while running an internal operation,
  # like :publish. Override this method to track these exceptions. The
  # default implementation re-raises the exception.
  def raised(op, ex)
    raise ex
  end

  # Run all the behaviors for this experiment, observing each and publishing
  # the results. Return the result of the named behavior, default "control".
  def run(name = "control")
    behaviors.freeze
    context.freeze

    name = name.to_s
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
      observations << Scientist::Observation.new(key, &block)
    end

    primary = observations.detect { |o| o.name == name }

    result = Scientist::Result.new self,
      observations: observations, primary: primary

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
  def try(name = "candidate", &block)
    name = name.to_s

    if behaviors.include?(name)
      raise Scientist::BehaviorNotUnique.new(self, name)
    end

    behaviors[name] = block
  end

  # Register the control behavior for this experiment.
  def use(&block)
    try("control", &block)
  end
end
