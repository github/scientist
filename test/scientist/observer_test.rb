describe Scientist::Observer do

  before do
    block1 = lambda {:block1}
    block2 = lambda {:block2}
    @behaviours = {:behaviour1 => block1, :behaviour2 => block2}
    @experiment = Scientist::Experiment.new 'test'
  end

  it 'observes the behaviours and records observations' do
    observer = Scientist::Observer.new @behaviours, @experiment
    observations = observer.observe

    assert_equal 2, observations.size

    observation = observations.detect {|o| o.name == :behaviour1}
    assert_equal :behaviour1, observation.name
    assert_equal @experiment, observation.experiment
    assert_equal :block1, observation.value
  end

  it 'observes the behaviours and returns specific observation' do
    observer = Scientist::Observer.new @behaviours, @experiment
    observation = observer.observation :behaviour1

    assert_equal :behaviour1, observation.name
    assert_equal @experiment, observation.experiment
    assert_equal :block1, observation.value
  end
end