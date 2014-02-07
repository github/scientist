require "scientist/experiment"

# A null experiment.
class Scientist::Default
  include Scientist::Experiment

  def enabled?
    true
  end

  def publish(payload)
  end
end
