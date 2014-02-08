module Scientist

  # Smoking in the bathroom and/or sassing.
  class BadBehavior < StandardError
    attr_reader :experiment
    attr_reader :behavior

    def initialize(experiment, behavior, message)
      @experiment = experiment
      @behavior = behavior

      super message
    end
  end

  class BehaviorMissing < BadBehavior
    def initialize(experiment, behavior)
      super experiment, behavior,
        "#{experiment.name} missing #{behavior} behavior"
    end
  end

  class BehaviorNotUnique < BadBehavior
    def initialize(experiment, behavior)
      super experiment, behavior,
        "#{experiment.name} alread has #{behavior} behavior"
    end
  end

  class NoValue < StandardError
    attr_reader :observation

    def initialize(observation)
      @observation = observation

      super "#{observation.name} doesn't have a value, it raised an exception"
    end
  end
end
