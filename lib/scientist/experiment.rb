# This mixin provides shared behavior for experiments. Includers must
# implement `enabled?` and `publish(result)`.
module Scientist::Experiment

  # Create a new instance of a class that implements the Scientist::Experiment
  # interface. Override `Scientist::Experiment.implementation` to change.
  def self.new(*args)
    implementation.new(*args)
  end

  # A class that includes + implements Scientist::Experiment. Override this
  # method to use a custom class in the `Scientist#scientist` helper.
  def self.implementation
    Scientist::Default
  end

  def behaviors
    @_scientist_behaviors ||= {}
  end

  def context(context = nil)
    @_scientist_context = context if !context.nil?
    @_scientist_context ||= {}
  end

  def name
    "experiment"
  end

  # Called when an exception is raised while running an internal operation,
  # like `:publish`. Override this method to track these exceptions. The
  # default implementation re-raises the exception.
  def raised(op, exception)
    raise exception
  end

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
    result = Scientist::Result.new(self, observations: observations, primary: primary)

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

  def try(name = "candidate", &block)
    name = name.to_s

    if behaviors.include?(name)
      raise Scientist::BehaviorNotUnique.new(self, name)
    end

    behaviors[name] = block
  end

  def use(&block)
    try("control", &block)
  end
end
