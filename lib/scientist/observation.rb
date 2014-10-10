# What happened when this named behavior was executed? Immutable.
class Scientist::Observation

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

  def initialize(name = "observation", &block)
    @name = name
    @now = Time.now

    begin
      @value = block.call
    rescue Object => e
      @exception = e
    end

    @duration = (Time.now - @now).to_f

    freeze
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

    values_are_equal = false
    both_raised      = other.raised? && raised?
    neither_raised   = !other.raised? && !raised?

    if neither_raised
      if block_given?
        values_are_equal = yield value, other.value
      else
        values_are_equal = value == other.value
      end
    end

    exceptions_are_equivalent = # backtraces will differ, natch
      both_raised &&
        other.exception.class == exception.class &&
          other.exception.message == exception.message

    (neither_raised && values_are_equal) ||
      (both_raised && exceptions_are_equivalent)
  end

  def hash
    [value, exception, self.class].compact.map(&:hash).inject(:^)
  end

  def raised?
    !exception.nil?
  end
end
