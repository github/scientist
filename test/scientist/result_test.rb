describe Scientist::Result do
  before do
    @experiment = Scientist::Experiment.new "experiment"
  end

  it "is immutable" do
    control = Scientist::Observation.new("control", @experiment)
    candidate = Scientist::Observation.new("candidate", @experiment)

    result = Scientist::Result.new @experiment,
      observations: [control, candidate], primary: control

    assert result.frozen?
  end

  it "evaluates its observations" do
    a = Scientist::Observation.new("a", @experiment) { 1 }
    b = Scientist::Observation.new("b", @experiment) { 1 }

    assert a.equivalent_to?(b)

    result = Scientist::Result.new @experiment, observations: [a, b], primary: a
    assert result.match?
    refute result.mismatch?
    assert_equal [], result.mismatched

    x = Scientist::Observation.new("x", @experiment) { 1 }
    y = Scientist::Observation.new("y", @experiment) { 2 }
    z = Scientist::Observation.new("z", @experiment) { 3 }

    result = Scientist::Result.new @experiment, observations: [x, y, z], primary: x
    refute result.match?
    assert result.mismatch?
    assert_equal [y, z], result.mismatched
  end

  it "has no mismatches if there is only a primary observation" do
    a = Scientist::Observation.new("a", @experiment) { 1 }
    result = Scientist::Result.new @experiment, observations: [a], primary: a
    assert result.match?
  end

  it "evaluates observations using the experiment's compare block" do
    a = Scientist::Observation.new("a", @experiment) { "1" }
    b = Scientist::Observation.new("b", @experiment) { 1 }

    @experiment.compare { |x, y| x == y.to_s }

    result = Scientist::Result.new @experiment, observations: [a, b], primary: a

    assert result.match?, result.mismatched
  end

  it "does not ignore any mismatches when nothing's ignored" do
    x = Scientist::Observation.new("x", @experiment) { 1 }
    y = Scientist::Observation.new("y", @experiment) { 2 }

    result = Scientist::Result.new @experiment, observations: [x, y], primary: x

    assert result.mismatch?
    refute result.ignored?
  end

  it "uses the experiment's ignore block to ignore mismatched observations" do
    x = Scientist::Observation.new("x", @experiment) { 1 }
    y = Scientist::Observation.new("y", @experiment) { 2 }
    called = false
    @experiment.ignore { called = true }

    result = Scientist::Result.new @experiment, observations: [x, y], primary: x

    refute result.mismatch?
    assert result.ignored?
    assert called
  end

  it "partitions observations into mismatched and ignored when applicable" do
    x = Scientist::Observation.new("x", @experiment) { :x }
    y = Scientist::Observation.new("y", @experiment) { :y }
    z = Scientist::Observation.new("z", @experiment) { :z }

    @experiment.ignore { |control, candidate| candidate.value == :y }

    result = Scientist::Result.new @experiment, observations: [x, y, z], primary: x

    assert result.mismatch?
    assert result.ignored?
    assert_equal [y], result.ignored
    assert_equal [z], result.mismatched
  end

  it "can retrieve its experiment's context" do
    @experiment.context :foo => :bar
    result = Scientist::Result.new @experiment,
      observations: [], primary: nil

    assert_equal({:foo => :bar}, result.context)
  end
end
