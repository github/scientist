module Scientist

  # Smoking in the bathroom and/or sassing.
  class BadBehavior < StandardError
    attr_reader :experiment
    attr_reader :name

    def initialize(experiment, name, message)
      @experiment = experiment
      @name = name

      super message
    end
  end

  class BehaviorMissing < BadBehavior
    def initialize(experiment, name)
      super experiment, name,
        "#{experiment.name} missing #{name} behavior"
    end
  end

  class BehaviorNotUnique < BadBehavior
    def initialize(experiment, name)
      super experiment, name,
        "#{experiment.name} already has #{name} behavior"
    end
  end

  class NoValue < StandardError
    attr_reader :observation

    def initialize(observation)
      @observation = observation
      super "#{observation.name} didn't return a value"
    end
  end
end
