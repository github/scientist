class Scientist::Observer
  def initialize(behaviours = [], experiment)
    @behaviours = behaviours
    @experiment = experiment
  end

  def observe
    @observations = []
    @behaviours.keys.shuffle.each do |key|
      block = @behaviours[key]
      @observations << Scientist::Observation.new(key, @experiment, &block)
    end
    @observations
  end

  def observation(name)
    @observations ||= observe
    @observations.detect { |o| o.name == name }
  end
end
