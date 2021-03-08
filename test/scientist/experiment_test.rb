describe Scientist::Experiment do
  class Fake
    include Scientist::Experiment

    # Undo auto-config magic / preserve default behavior of Scientist::Experiment.new
    Scientist::Experiment.set_default(nil)

    def initialize(*args)
    end

    def enabled?
      true
    end

    attr_reader :published_result

    def exceptions
      @exceptions ||= []
    end

    def raised(op, exception)
      exceptions << [op, exception]
    end

    def publish(result)
      @published_result = result
    end
  end

  before do
    @ex = Fake.new
  end

  it "sets the default on inclusion" do
    klass = Class.new do
      include Scientist::Experiment

      def initialize(name)
      end
    end

    assert_kind_of klass, Scientist::Experiment.new("hello")

    Scientist::Experiment.set_default(nil)
  end

  it "doesn't set the default on inclusion when it's a module" do
    Module.new { include Scientist::Experiment }
    assert_kind_of Scientist::Default, Scientist::Experiment.new("hello")
  end

  it "has a default implementation" do
    ex = Scientist::Experiment.new("hello")
    assert_kind_of Scientist::Default, ex
    assert_equal "hello", ex.name
  end

  it "provides a static default name" do
    assert_equal "experiment", Fake.new.name
  end

  it "requires includers to implement enabled?" do
    obj = Object.new
    obj.extend Scientist::Experiment

    assert_raises NoMethodError do
      obj.enabled?
    end
  end

  it "requires includers to implement publish" do
    obj = Object.new
    obj.extend Scientist::Experiment

    assert_raises NoMethodError do
      obj.publish("result")
    end
  end

  it "can't be run without a control behavior" do
    e = assert_raises Scientist::BehaviorMissing do
      @ex.run
    end

    assert_equal "control", e.name
  end

  it "is a straight pass-through with only a control behavior" do
    @ex.use { "control" }
    assert_equal "control", @ex.run
  end

  it "runs other behaviors but always returns the control" do
    @ex.use { "control" }
    @ex.try { "candidate" }

    assert_equal "control", @ex.run
  end

  it "complains about duplicate behavior names" do
    @ex.use { "control" }

    e = assert_raises Scientist::BehaviorNotUnique do
      @ex.use { "control-again" }
    end

    assert_equal @ex, e.experiment
    assert_equal "control", e.name
  end

  it "swallows exceptions raised by candidate behaviors" do
    @ex.use { "control" }
    @ex.try { raise "candidate" }

    assert_equal "control", @ex.run
  end

  it "passes through exceptions raised by the control behavior" do
    @ex.use { raise "control" }
    @ex.try { "candidate" }

    exception = assert_raises RuntimeError do
      @ex.run
    end

    assert_equal "control", exception.message
  end

  it "shuffles behaviors before running" do
    last = nil
    runs = []

    @ex.use { last = "control" }
    @ex.try { last = "candidate" }

    10000.times do
      @ex.run
      runs << last
    end

    assert runs.uniq.size > 1
  end

  it "re-raises exceptions raised during publish by default" do
    ex = Scientist::Experiment.new("hello")
    assert_kind_of Scientist::Default, ex

    def ex.enabled?
      true
    end

    def ex.publish(result)
      raise "boomtown"
    end

    ex.use { "control" }
    ex.try { "candidate" }

    exception = assert_raises RuntimeError do
      ex.run
    end

    assert_equal "boomtown", exception.message
  end

  it "reports publishing errors" do
    def @ex.publish(result)
      raise "boomtown"
    end

    @ex.use { "control" }
    @ex.try { "candidate" }

    assert_equal "control", @ex.run

    op, exception = @ex.exceptions.pop

    assert_equal :publish, op
    assert_equal "boomtown", exception.message
  end

  it "publishes results" do
    @ex.use { 1 }
    @ex.try { 1 }
    assert_equal 1, @ex.run
    assert @ex.published_result
  end

  it "does not publish results when there is only a control value" do
    @ex.use { 1 }
    assert_equal 1, @ex.run
    assert_nil @ex.published_result
  end

  it "compares results with a comparator block if provided" do
    @ex.compare { |a, b| a == b.to_s }
    @ex.use { "1" }
    @ex.try { 1 }

    assert_equal "1", @ex.run
    assert @ex.published_result.matched?
  end

  it "knows how to compare two experiments" do
    a = Scientist::Observation.new(@ex, "a") { 1 }
    b = Scientist::Observation.new(@ex, "b") { 2 }

    assert @ex.observations_are_equivalent?(a, a)
    refute @ex.observations_are_equivalent?(a, b)
  end

  it "uses a compare block to determine if observations are equivalent" do
    a = Scientist::Observation.new(@ex, "a") { "1" }
    b = Scientist::Observation.new(@ex, "b") { 1 }
    @ex.compare { |x, y| x == y.to_s }
    assert @ex.observations_are_equivalent?(a, b)
  end

  it "reports errors in a compare block" do
    @ex.compare { raise "boomtown" }
    @ex.use { "control" }
    @ex.try { "candidate" }

    assert_equal "control", @ex.run

    op, exception = @ex.exceptions.pop

    assert_equal :compare, op
    assert_equal "boomtown", exception.message
  end

  it "reports errors in the enabled? method" do
    def @ex.enabled?
      raise "kaboom"
    end

    @ex.use { "control" }
    @ex.try { "candidate" }
    assert_equal "control", @ex.run

    op, exception = @ex.exceptions.pop

    assert_equal :enabled, op
    assert_equal "kaboom", exception.message
  end

  it "reports errors in a run_if block" do
    @ex.run_if { raise "kaboom" }
    @ex.use { "control" }
    @ex.try { "candidate" }
    assert_equal "control", @ex.run

    op, exception = @ex.exceptions.pop

    assert_equal :run_if, op
    assert_equal "kaboom", exception.message
  end

  it "returns the given value when no clean block is configured" do
    assert_equal 10, @ex.clean_value(10)
  end

  it "provides the clean block when asked for it, in case subclasses wish to override and provide defaults" do
    assert_nil @ex.cleaner
    cleaner = ->(value) { value.upcase }
    @ex.clean(&cleaner)
    assert_equal cleaner, @ex.cleaner
  end

  it "calls the configured clean block with a value when configured" do
    @ex.clean do |value|
      value.upcase
    end

    assert_equal "TEST", @ex.clean_value("test")
  end

  it "reports an error and returns the original value when an error is raised in a clean block" do
    @ex.clean { |value| raise "kaboom" }

    @ex.use { "control" }
    @ex.try { "candidate" }
    assert_equal "control", @ex.run

    assert_equal "control", @ex.published_result.control.cleaned_value

    op, exception = @ex.exceptions.pop

    assert_equal :clean, op
    assert_equal "kaboom", exception.message
  end

  describe "#raise_with" do
    it "raises custom error if provided" do
      CustomError = Class.new(Scientist::Experiment::MismatchError)

      @ex.use { 1 }
      @ex.try { 2 }
      @ex.raise_with(CustomError)
      @ex.raise_on_mismatches = true

      assert_raises(CustomError) { @ex.run }
    end
  end

  describe "#run_if" do
    it "does not run the experiment if the given block returns false" do
      candidate_ran = false
      run_check_ran = false

      @ex.use { 1 }
      @ex.try { candidate_ran = true; 1 }

      @ex.run_if { run_check_ran = true; false }

      @ex.run

      assert run_check_ran
      refute candidate_ran
    end

    it "runs the experiment if the given block returns true" do
      candidate_ran = false
      run_check_ran = false

      @ex.use { true }
      @ex.try { candidate_ran = true }

      @ex.run_if { run_check_ran = true }

      @ex.run

      assert run_check_ran
      assert candidate_ran
    end
  end

  describe "#ignore_mismatched_observation?" do
    before do
      @a = Scientist::Observation.new(@ex, "a") { 1 }
      @b = Scientist::Observation.new(@ex, "b") { 2 }
    end

    it "does not ignore an observation if no ignores are configured" do
      refute @ex.ignore_mismatched_observation?(@a, @b)
    end

    it "calls a configured ignore block with the given observed values" do
      called = false
      @ex.ignore do |a, b|
        called = true
        assert_equal @a.value, a
        assert_equal @b.value, b
        true
      end

      assert @ex.ignore_mismatched_observation?(@a, @b)
      assert called
    end

    it "calls multiple ignore blocks to see if any match" do
      called_one = called_two = called_three = false
      @ex.ignore { |a, b| called_one   = true; false }
      @ex.ignore { |a, b| called_two   = true; false }
      @ex.ignore { |a, b| called_three = true; false }
      refute @ex.ignore_mismatched_observation?(@a, @b)
      assert called_one
      assert called_two
      assert called_three
    end

    it "only calls ignore blocks until one matches" do
      called_one = called_two = called_three = false
      @ex.ignore { |a, b| called_one   = true; false }
      @ex.ignore { |a, b| called_two   = true; true  }
      @ex.ignore { |a, b| called_three = true; false }
      assert @ex.ignore_mismatched_observation?(@a, @b)
      assert called_one
      assert called_two
      refute called_three
    end

    it "reports exceptions raised in an ignore block and returns false" do
      def @ex.exceptions
        @exceptions ||= []
      end

      def @ex.raised(op, exception)
        exceptions << [op, exception]
      end

      @ex.ignore { raise "kaboom" }

      refute @ex.ignore_mismatched_observation?(@a, @b)

      op, exception = @ex.exceptions.pop
      assert_equal :ignore, op
      assert_equal "kaboom", exception.message
    end

    it "skips ignore blocks that raise and tests any remaining blocks if an exception is swallowed" do
      def @ex.exceptions
        @exceptions ||= []
      end

      # this swallows the exception rather than re-raising
      def @ex.raised(op, exception)
        exceptions << [op, exception]
      end

      @ex.ignore { raise "kaboom" }
      @ex.ignore { true }

      assert @ex.ignore_mismatched_observation?(@a, @b)
      assert_equal 1, @ex.exceptions.size
    end
  end

  describe "raising on mismatches" do
    before do
      @old_raise_on_mismatches = Fake.raise_on_mismatches?
    end

    after do
      Fake.raise_on_mismatches = @old_raise_on_mismatches
    end

    it "raises when there is a mismatch if raise on mismatches is enabled" do
      Fake.raise_on_mismatches = true
      @ex.use { "fine" }
      @ex.try { "not fine" }

      assert_raises(Scientist::Experiment::MismatchError) { @ex.run }
    end

    it "cleans values when raising on observation mismatch" do
      Fake.raise_on_mismatches = true
      @ex.use { "fine" }
      @ex.try { "not fine" }
      @ex.clean { "So Clean" }

      err = assert_raises(Scientist::Experiment::MismatchError) { @ex.run }
      assert_match /So Clean/, err.message
    end

    it "doesn't raise when there is a mismatch if raise on mismatches is disabled" do
      Fake.raise_on_mismatches = false
      @ex.use { "fine" }
      @ex.try { "not fine" }

      assert_equal "fine", @ex.run
    end

    it "raises a mismatch error if the control raises and candidate doesn't" do
      Fake.raise_on_mismatches = true
      @ex.use { raise "control" }
      @ex.try { "candidate" }
      assert_raises(Scientist::Experiment::MismatchError) { @ex.run }
    end

    it "raises a mismatch error if the candidate raises and the control doesn't" do
      Fake.raise_on_mismatches = true
      @ex.use { "control" }
      @ex.try { raise "candidate" }
      assert_raises(Scientist::Experiment::MismatchError) { @ex.run }
    end

    it "allows MismatchError to bubble up through bare rescues" do
      Fake.raise_on_mismatches = true
      @ex.use { "control" }
      @ex.try { "candidate" }
      runner = -> {
        begin
          @ex.run
        rescue
          # StandardError handled
        end
      }
      assert_raises(Scientist::Experiment::MismatchError) { runner.call }
    end

    describe "#raise_on_mismatches?" do
      it "raises when there is a mismatch if the experiment instance's raise on mismatches is enabled" do
        Fake.raise_on_mismatches = false
        @ex.raise_on_mismatches = true
        @ex.use { "fine" }
        @ex.try { "not fine" }

        assert_raises(Scientist::Experiment::MismatchError) { @ex.run }
      end

      it "doesn't raise when there is a mismatch if the experiment instance's raise on mismatches is disabled" do
        Fake.raise_on_mismatches = true
        @ex.raise_on_mismatches = false
        @ex.use { "fine" }
        @ex.try { "not fine" }

        assert_equal "fine", @ex.run
      end

      it "respects the raise_on_mismatches class attribute by default" do
        Fake.raise_on_mismatches = false
        @ex.use { "fine" }
        @ex.try { "not fine" }

        assert_equal "fine", @ex.run

        Fake.raise_on_mismatches = true

        assert_raises(Scientist::Experiment::MismatchError) { @ex.run }
      end
    end

    describe "MismatchError" do
      before do
        Fake.raise_on_mismatches = true
        @ex.use { :foo }
        @ex.try { :bar }
        begin
          @ex.run
        rescue Scientist::Experiment::MismatchError => e
          @mismatch = e
        end
        assert @mismatch
      end

      it "has the name of the experiment" do
        assert_equal @ex.name, @mismatch.name
      end

      it "includes the experiments' results" do
        assert_equal @ex.published_result, @mismatch.result
      end

      it "formats nicely as a string" do
        assert_equal <<-STR, @mismatch.to_s
experiment 'experiment' observations mismatched:
control:
  :foo
candidate:
  :bar
        STR
      end

      it "includes the backtrace when an observation raises" do
        mismatch = nil
        ex = Fake.new
        ex.use { "value" }
        ex.try { raise "error" }

        begin
          ex.run
        rescue Scientist::Experiment::MismatchError => e
          mismatch = e
        end

        # Should look like this:
        # experiment 'experiment' observations mismatched:
        # control:
        #   "value"
        # candidate:
        #   #<RuntimeError: error>
        #     test/scientist/experiment_test.rb:447:in `block (5 levels) in <top (required)>'
        # ... (more backtrace)
        lines = mismatch.to_s.split("\n")
        assert_equal "control:", lines[1]
        assert_equal "  \"value\"", lines[2]
        assert_equal "candidate:", lines[3]
        assert_equal "  #<RuntimeError: error>", lines[4]
        assert_match %r(test/scientist/experiment_test.rb:\d+:in `block), lines[5]
      end
    end
  end

  describe "before run block" do
    it "runs when an experiment is enabled" do
      control_ok = candidate_ok = false
      before = false
      @ex.before_run { before = true }
      @ex.use { control_ok = before }
      @ex.try { candidate_ok = before }

      @ex.run

      assert before, "before_run should have run"
      assert control_ok, "control should have run after before_run"
      assert candidate_ok, "candidate should have run after before_run"
    end

    it "does not run when an experiment is disabled" do
      before = false

      def @ex.enabled?
        false
      end
      @ex.before_run { before = true }
      @ex.use { "value" }
      @ex.try { "value" }
      @ex.run

      refute before, "before_run should not have run"
    end
  end

  describe "testing hooks for extending code" do
    it "allows a user to provide fabricated durations for testing purposes" do
      @ex.use { true }
      @ex.try { true }
      @ex.fabricate_durations_for_testing_purposes( "control" => 0.5, "candidate" => 1.0 )

      @ex.run

      cont = @ex.published_result.control
      cand = @ex.published_result.candidates.first
      assert_in_delta 0.5, cont.duration, 0.01
      assert_in_delta 1.0, cand.duration, 0.01
    end

    it "returns actual durations if fabricated ones are omitted for some blocks" do
      @ex.use { true }
      @ex.try { sleep 0.1; true }
      @ex.fabricate_durations_for_testing_purposes( "control" => 0.5 )

      @ex.run

      cont = @ex.published_result.control
      cand = @ex.published_result.candidates.first
      assert_in_delta 0.5, cont.duration, 0.01
      assert_in_delta 0.1, cand.duration, 0.01
    end
  end
end
