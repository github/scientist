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
end
