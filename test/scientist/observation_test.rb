describe Scientist::Observation do
  it "takes an optional name" do
    assert_equal "observation", Scientist::Observation.new{}.name
    assert_equal "name", Scientist::Observation.new("name"){}.name
  end

  it "observes and records the execution of a block" do
    ob = Scientist::Observation.new do
      sleep 0.1
      "ret"
    end

    assert_equal "ret", ob.value
    refute ob.raised?
    assert_in_delta 0.1, ob.duration, 0.01
  end

  it "stashes exceptions" do
    ob = Scientist::Observation.new do
      raise "exception"
    end

    assert ob.raised?
    assert_equal "exception", ob.exception.message
    assert_nil ob.value
  end

  it "compares values" do
    a = Scientist::Observation.new { 1 }
    b = Scientist::Observation.new { 1 }

    assert a.equivalent_to?(b)

    x = Scientist::Observation.new { 1 }
    y = Scientist::Observation.new { 2 }

    refute x.equivalent_to?(y)
  end

  it "compares exception messages" do
    a = Scientist::Observation.new { raise "error" }
    b = Scientist::Observation.new { raise "error" }

    assert a.equivalent_to?(b)

    x = Scientist::Observation.new { raise "error" }
    y = Scientist::Observation.new { raise "ERROR" }

    refute x.equivalent_to?(y)
  end

  FirstErrror = Class.new(StandardError)
  SecondError = Class.new(StandardError)

  it "compares exception classes" do
    x = Scientist::Observation.new { raise FirstError, "error" }
    y = Scientist::Observation.new { raise SecondError, "error" }
    z = Scientist::Observation.new { raise FirstError, "error" }

    assert x.equivalent_to?(z)
    refute x.equivalent_to?(y)
  end

  it "compares values using a comparator block" do
    a = Scientist::Observation.new { 1 }
    b = Scientist::Observation.new { "1" }

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

end
