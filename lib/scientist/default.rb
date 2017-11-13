require "scientist/experiment"

# A null experiment.
class Scientist::Default
  include Scientist::Experiment

  attr_reader :name

  def initialize(name)
    @name = name
  end

  # Don't run experiments.
  def enabled?
    false
  end

  # Don't publish anything.
  def publish(result)
  end
end
