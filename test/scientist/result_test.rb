describe Scientist::Result do
  it "is immutable" do
    control = Scientist::Observation.new("control")
    candidate = Scientist::Observation.new("candidate")

    result = Scientist::Result.new nil,
      observations: [control, candidate], primary: control

    assert result.frozen?
  end

  it "evaluates its observations" do
    a = Scientist::Observation.new("a") { 1 }
    b = Scientist::Observation.new("b") { 1 }

    assert a.equivalent_to?(b)

    result = Scientist::Result.new nil, observations: [a, b], primary: a
    assert result.match?
    refute result.mismatch?
    assert_equal [], result.mismatched

    x = Scientist::Observation.new("x") { 1 }
    y = Scientist::Observation.new("y") { 2 }
    z = Scientist::Observation.new("z") { 3 }

    result = Scientist::Result.new nil, observations: [x, y, z], primary: x
    refute result.match?
    assert result.mismatch?
    assert_equal [y, z], result.mismatched
  end

  it "has no mismatches if there is only a primary observation" do
    a = Scientist::Observation.new("a") { 1 }
    result = Scientist::Result.new nil, observations: [a], primary: a
    assert result.match?
  end
end
