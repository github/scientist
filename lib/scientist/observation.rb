# What happened when this named behavior was executed? Immutable.
class Scientist::Observation

  # The experiment this observation is for
  attr_reader :experiment

  # The instant observation began.
  attr_reader :now

  # The String name of the behavior.
  attr_reader :name

  # The value returned, if any.
  attr_reader :value

  # The raised exception, if any.
  attr_reader :exception

  # The Float seconds elapsed.
  attr_reader :duration

  def initialize(name, experiment, &block)
    @name       = name
    @experiment = experiment
    @now        = Time.now

    begin
      @value = block.call
    rescue StandardError => e
      @exception = e
    end

    @duration = (Time.now - @now).to_f

    freeze
  end

  # Return a cleaned value suitable for publishing. Uses the experiment's
  # defined cleaner block to clean the observed value.
  def cleaned_value
    experiment.clean_value value unless value.nil?
  end

  # Is this observation equivalent to another?
  #
  # other      - the other Observation in question
  # comparator - an optional comparison block. This observation's value and the
  #              other observation's value are yielded to this to determine
  #              their equivalency. Block should return true/false.
  #
  # Returns true if:
  #
  # * The values of the observation are equal (using `==`)
  # * The values of the observations are equal according to a comparison
  #   block, if given
  # * Both observations raised an exception with the same class and message.
  #
  # Returns false otherwise.
  def equivalent_to?(other, &comparator)
    return false unless other.is_a?(Scientist::Observation)

    if raised? || other.raised?
      return other.exception.class == exception.class &&
        other.exception.message == exception.message
    end

    if comparator
      comparator.call(value, other.value)
    else
      value == other.value
    end
  end

  def hash
    [value, exception, self.class].compact.map(&:hash).inject(:^)
  end

  def raised?
    !exception.nil?
  end
end
