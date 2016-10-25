describe Scientist::Observation do

  before do
    @experiment = Scientist::Experiment.new "test"
  end

  it "observes and records the execution of a block" do
    ob = Scientist::Observation.new("test", @experiment) do
      sleep 0.1
      "ret"
    end

    assert_equal "ret", ob.value
    refute ob.raised?
    assert_in_delta 0.1, ob.duration, 0.01
  end

  it "stashes exceptions" do
    ob = Scientist::Observation.new("test", @experiment) do
      raise "exception"
    end

    assert ob.raised?
    assert_equal "exception", ob.exception.message
    assert_nil ob.value
  end

  it "compares values" do
    a = Scientist::Observation.new("test", @experiment) { 1 }
    b = Scientist::Observation.new("test", @experiment) { 1 }

    assert a.equivalent_to?(b)

    x = Scientist::Observation.new("test", @experiment) { 1 }
    y = Scientist::Observation.new("test", @experiment) { 2 }

    refute x.equivalent_to?(y)
  end

  it "compares exception messages" do
    a = Scientist::Observation.new("test", @experiment) { raise "error" }
    b = Scientist::Observation.new("test", @experiment) { raise "error" }

    assert a.equivalent_to?(b)

    x = Scientist::Observation.new("test", @experiment) { raise "error" }
    y = Scientist::Observation.new("test", @experiment) { raise "ERROR" }

    refute x.equivalent_to?(y)
  end

  FirstErrror = Class.new(StandardError)
  SecondError = Class.new(StandardError)

  it "compares exception classes" do
    x = Scientist::Observation.new("test", @experiment) { raise FirstError, "error" }
    y = Scientist::Observation.new("test", @experiment) { raise SecondError, "error" }
    z = Scientist::Observation.new("test", @experiment) { raise FirstError, "error" }

    assert x.equivalent_to?(z)
    refute x.equivalent_to?(y)
  end

  it "compares values using a comparator block" do
    a = Scientist::Observation.new("test", @experiment) { 1 }
    b = Scientist::Observation.new("test", @experiment) { "1" }

    refute a.equivalent_to?(b)
    assert a.equivalent_to?(b) { |x, y| x.to_s == y.to_s }

    yielded = []
    a.equivalent_to?(b) do |x, y|
      yielded << x
      yielded << y
      true
    end
    assert_equal [a.value, b.value], yielded
  end

  describe "#cleaned_value" do
    it "returns the observation's value by default" do
      a = Scientist::Observation.new("test", @experiment) { 1 }
      assert_equal 1, a.cleaned_value
    end

    it "uses the experiment's clean block to clean a value when configured" do
      @experiment.clean { |value| value.upcase }
      a = Scientist::Observation.new("test", @experiment) { "test" }
      assert_equal "TEST", a.cleaned_value
    end

    it "doesn't clean nil values" do
      @experiment.clean { |value| "foo" }
      a = Scientist::Observation.new("test", @experiment) { nil }
      assert_nil a.cleaned_value
    end

    it "cleans false values" do
      @experiment.clean { |value| value.to_s.upcase }
      a = Scientist::Observation.new("test", @experiment) { false }
      assert_equal "FALSE", a.cleaned_value
    end
  end

end
