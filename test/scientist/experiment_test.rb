describe Scientist::Experiment do
  class Fake
    include Scientist::Experiment

    def enabled?
      true
    end

    attr_reader :published_result

    def publish(result)
      @published_result = result
    end
  end

  before do
    @ex = Fake.new
  end

  it "has a default implementation" do
    ex = Scientist::Experiment.new("hello")
    assert_kind_of Scientist::Default, ex
    assert_equal "hello", ex.name
  end

  it "provides a static default name" do
    assert_equal "experiment", Fake.new.name
  end

  it "requires includers to implement enabled?" do
    obj = Object.new
    obj.extend Scientist::Experiment

    assert_raises NoMethodError do
      obj.enabled?
    end
  end

  it "requires includers to implement publish" do
    obj = Object.new
    obj.extend Scientist::Experiment

    assert_raises NoMethodError do
      obj.publish("result")
    end
  end

  it "can't be run without a control behavior" do
    e = assert_raises Scientist::BehaviorMissing do
      @ex.run
    end

    assert_equal "control", e.name
  end

  it "is a straight pass-through with only a control behavior" do
    @ex.use { "control" }
    assert_equal "control", @ex.run
  end

  it "runs other behaviors but always returns the control" do
    @ex.use { "control" }
    @ex.try { "candidate" }

    assert_equal "control", @ex.run
  end

  it "complains about duplicate behavior names" do
    @ex.use { "control" }

    e = assert_raises Scientist::BehaviorNotUnique do
      @ex.use { "control-again" }
    end

    assert_equal @ex, e.experiment
    assert_equal "control", e.name
  end

  it "swallows exceptions raised by candidate behaviors" do
    @ex.use { "control" }
    @ex.try { raise "candidate" }

    assert_equal "control", @ex.run
  end

  it "passes through exceptions raised by the control behavior" do
    @ex.use { raise "control" }
    @ex.try { "candidate" }

    exception = assert_raises RuntimeError do
      @ex.run
    end

    assert_equal "control", exception.message
  end

  it "shuffles behaviors before running" do
    last = nil
    runs = []

    @ex.use { last = "control" }
    @ex.try { last = "candidate" }

    10000.times do
      @ex.run
      runs << last
    end

    assert runs.uniq.size > 1
  end

  it "re-raises exceptions raised during publish by default" do
    def @ex.publish(result)
      raise "boomtown"
    end

    @ex.use { "control" }
    @ex.try { "candidate" }

    exception = assert_raises RuntimeError do
      @ex.run
    end

    assert_equal "boomtown", exception.message
  end

  it "can be overridden to report publishing errors" do
    def @ex.publish(result)
      raise "boomtown"
    end

    def @ex.exceptions
      @exceptions ||= []
    end

    def @ex.raised(op, exception)
      exceptions << [op, exception]
    end

    @ex.use { "control" }
    @ex.try { "candidate" }

    assert_equal "control", @ex.run

    op, exception = @ex.exceptions.pop

    assert_equal :publish, op
    assert_equal "boomtown", exception.message
  end

  it "publishes results" do
    @ex.use { 1 }
    @ex.try { 1 }
    assert_equal 1, @ex.run
    assert @ex.published_result
  end

  it "does not publish results when there is only a control value" do
    @ex.use { 1 }
    assert_equal 1, @ex.run
    assert_nil @ex.published_result
  end

  it "compares results with a comparator block if provided" do
    @ex.compare { |a, b| a == b.to_s }
    @ex.use { "1" }
    @ex.try { 1 }

    assert_equal "1", @ex.run
    assert @ex.published_result.match?
  end

  it "knows how to compare two experiments" do
    a = Scientist::Observation.new(@ex, "a") { 1 }
    b = Scientist::Observation.new(@ex, "b") { 2 }

    assert @ex.observations_are_equivalent?(a, a)
    refute @ex.observations_are_equivalent?(a, b)
  end

  it "uses a compare block to determine if observations are equivalent" do
    a = Scientist::Observation.new(@ex, "a") { "1" }
    b = Scientist::Observation.new(@ex, "b") { 1 }
    @ex.compare { |x, y| x == y.to_s }
    assert @ex.observations_are_equivalent?(a, b)
  end

  it "includes an experiment's context in a published result" do
    @ex.context :foo => :bar
    @ex.use { 1 }
    @ex.try { 1 }
    @ex.run
    assert_equal({:foo => :bar}, @ex.published_result.context)
  end

  it "reports errors in a compare block" do
    def @ex.exceptions
      @exceptions ||= []
    end

    def @ex.raised(op, exception)
      exceptions << [op, exception]
    end

    @ex.compare { raise "boomtown" }

    @ex.use { "control" }
    @ex.try { "candidate" }

    assert_equal "control", @ex.run

    op, exception = @ex.exceptions.pop

    assert_equal :compare, op
    assert_equal "boomtown", exception.message
  end

  it "returns the given value when no clean block is configured" do
    assert_equal 10, @ex.clean_value(10)
  end

  it "calls the configured clean block with a value when configured" do
    @ex.clean do |value|
      value.upcase
    end

    assert_equal "TEST", @ex.clean_value("test")
  end
end
