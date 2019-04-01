describe Scientist do
  it "has a version or whatever" do
    assert Scientist::VERSION
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

  it "provides a module method to instantiate and run experiments" do
    r = Scientist.run "test" do |e|
      e.use { :control }
      e.try { :candidate }
    end

    assert_equal :control, r
  end

  it "provides an empty default_scientist_context" do
    obj = Object.new
    obj.extend(Scientist)

    assert_equal Hash.new, obj.default_scientist_context
  end

  it "respects default_scientist_context" do
    obj = Object.new
    obj.extend(Scientist)

    def obj.default_scientist_context
      { :default => true }
    end

    experiment = nil

    obj.science "test" do |e|
      experiment = e
      e.context :inline => true
      e.use { }
    end

    refute_nil experiment
    assert_equal true, experiment.context[:default]
    assert_equal true, experiment.context[:inline]
  end

  it "runs the named test instead of the control" do
    obj = Object.new
    obj.extend(Scientist)

    behaviors_executed = []

    result = obj.science "test", run: "first-way" do |e|
      e.try("first-way") { behaviors_executed << "first-way" ; true }
      e.try("second-way") { behaviors_executed << "second-way" ; true }
    end

    assert_equal true, result
    assert_equal [ "first-way" ], behaviors_executed
  end

  it "runs control when there is a nil named test" do
    obj = Object.new
    obj.extend(Scientist)

    behaviors_executed = []

    result = obj.science "test", nil do |e|
      e.use { behaviors_executed << "control" ; true }
      e.try("second-way") { behaviors_executed << "second-way" ; true }
    end

    assert_equal true, result
    assert_equal [ "control" ], behaviors_executed
  end
end
