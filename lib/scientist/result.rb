# The result of running an experiment.
class Scientist::Result
  attr_reader :observations

  def initialize(primary, observations)
    @observations = observations
  end
end
