describe Scientist::Result do
  it "is immutable" do
    control = Scientist::Observation.new("control")
    candidate = Scientist::Observation.new("candidate")

    result = Scientist::Result.new nil,
      observations: [control, candidate], primary: control

    assert result.frozen?
  end
end
