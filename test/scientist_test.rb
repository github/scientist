describe Scientist do
  before do
    Scientist.reset
  end

  it "has a version or whatever" do
    assert Scientist::VERSION
  end

  it "uses a noop as the default experiment class" do
    assert_equal Scientist::Default, Scientist.experiment
  end

  it "provides a helper to instantiate and run experiments" do
    obj = Object.new
    obj.extend(Scientist)

    r = obj.science "test" do |e|
      e.use { :control }
      e.try { :candidate }
    end

    assert_equal :control, r
  end
end
