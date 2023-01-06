# What happened when this named behavior was executed? Immutable.
class Scientist::Observation

  # An Array of Exception types to rescue when initializing an observation.
  # NOTE: This Array will change to `[StandardError]` in the next major release.
  RESCUES = [Exception]

  # The experiment this observation is for
  attr_reader :experiment

  # The String name of the behavior.
  attr_reader :name

  # The value returned, if any.
  attr_reader :value

  # The raised exception, if any.
  attr_reader :exception

  # The Float seconds elapsed.
  attr_reader :duration

  def initialize(name, experiment, fabricated_duration: nil, &block)
    @name       = name
    @experiment = experiment

    starting = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second) unless fabricated_duration
    begin
      @value = block.call
    rescue *RESCUES => e
      @exception = e
    end

    @duration = fabricated_duration ||
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second) - starting

    freeze
  end

  # Return a cleaned value suitable for publishing. Uses the experiment's
  # defined cleaner block to clean the observed value.
  def cleaned_value
    experiment.clean_value value unless value.nil?
  end

  # Is this observation equivalent to another?
  #
  # other            - the other Observation in question
  # comparator       - an optional comparison proc. This observation's value and the
  #                    other observation's value are passed to this to determine
  #                    their equivalency. Proc should return true/false.
  # error_comparator - an optional comparison proc. This observation's Error and the
  #                    other observation's Error are passed to this to determine
  #                    their equivalency. Proc should return true/false.
  #
  # Returns true if:
  #
  # * The values of the observation are equal (using `==`)
  # * The values of the observations are equal according to a comparison
  #   proc, if given
  # * The exceptions raised by the observations are equal according to the
  #   error comparison proc, if given.
  # * Both observations raised an exception with the same class and message.
  #
  # Returns false otherwise.
  def equivalent_to?(other, comparator=nil, error_comparator=nil)
    return false unless other.is_a?(Scientist::Observation)

    if raised? || other.raised?
      if error_comparator
        return error_comparator.call(exception, other.exception)
      else
        return other.exception.class == exception.class &&
          other.exception.message == exception.message
      end
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
