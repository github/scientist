require "scientist/experiment"

# A null experiment.
class Scientist::Default
  include Scientist::Experiment

  attr_reader :name

  def initialize(name)
    @name = name
  end

  # Run everything every time.
  def enabled?
    true
  end

  # Don't publish anything.
  def publish(payload)
  end
end
