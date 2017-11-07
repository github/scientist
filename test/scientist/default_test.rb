describe Scientist::Default do
  before do
    @ex = Scientist::Default.new "default"
  end

  it "is always disabled" do
    refute @ex.enabled?
  end

  it "noops publish" do
    assert_nil @ex.publish("data")
  end

  it "is an experiment" do
    assert Scientist::Default < Scientist::Experiment
  end

  it "reraises when an internal action raises" do
     assert_raises RuntimeError do
       @ex.raised :publish, RuntimeError.new("kaboom")
     end
  end
end
