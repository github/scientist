# This mixin provides shared behavior for experiments. Includers must
# implement enabled? and publish(result).
module Scientist::Experiment
  attr_reader :name
  attr_reader :behaviors

  def initialize(name = "experiment", &block)
    @name = name
    @behaviors = {}

    yield self if !block.nil?
  end

  def run(primary = "control")
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
