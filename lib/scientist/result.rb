# The result of running an experiment.
class Scientist::Result
  attr_reader :observations

  def initialize(observations)
    @observations = observations
  end
end
