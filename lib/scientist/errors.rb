module Scientist
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
end
