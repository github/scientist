describe Scientist::Default do
  before do
    @ex = Scientist::Default.new "default"
  end

  it "is always enabled" do
    assert @ex.enabled?
  end

  it "noops publish" do
    assert_nil @ex.publish("data")
  end

  it "is an experiment" do
    assert Scientist::Default < Scientist::Experiment
  end
end
