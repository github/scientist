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

  def run(primary = "control")
    behaviors.freeze
    context.freeze
    
    primary = primary.to_s
    block = behaviors[primary]

    if block.nil?
      raise Scientist::BehaviorMissing.new(self, primary)
    end

    if behaviors.size == 1 || !enabled?
      return block.call
    end

    observations = []

    behaviors.keys.shuffle.each do |name|
      block = behaviors[name]
      observations << Scientist::Observation.new(name, &block)
    end

    use = observations.detect { |o| o.name == primary }
    result = Scientist::Result.new(self, observations, primary)

    publish(result)

    if use.raised?
      raise use.exception
    end

    use.value
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
