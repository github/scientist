describe Scientist::Experiment do
  class Fake
    include Scientist::Experiment

    def enabled?
      true
    end

    def publish(result)
    end
  end

  before do
    @ex = Fake.new("test-experiment")
  end

  it "takes a name" do
    ex = Fake.new "name"
    assert_equal "name", ex.name
  end

  it "yields itself to a block when initialized" do
    yielded = nil
    ex = Fake.new("name") { |e| yielded = e }

    assert_same ex, yielded
  end

  it "requires includers to implement enabled?" do
    obj = Object.new
    obj.extend Scientist::Experiment

    assert_raises NoMethodError do
      obj.enabled?
    end
  end

  it "requires includers to implement perform" do
    obj = Object.new
    obj.extend Scientist::Experiment

    assert_raises NoMethodError do
      obj.perform("payload")
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
end
