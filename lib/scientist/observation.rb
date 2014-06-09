# What happened when this named behavior was executed? Immutable.
class Scientist::Observation

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
    start = Time.now

    begin
      @value = block.call
    rescue Object => e
      @exception = e
    end

    @duration = (Time.now - start).to_f

    freeze
  end

  def ==(other)
    return false unless other.is_a?(Scientist::Observation)

    values_are_equal = other.value == value
    both_raised      = other.raised? && raised?
    neither_raised   = !other.raised? && !raised?

    exceptions_are_equivalent = # backtraces will differ, natch
      both_raised &&
        other.exception.class == exception.class &&
          other.exception.message == exception.message

    (values_are_equal && neither_raised) ||
      (both_raised && exceptions_are_equivalent)
  end

  def hash
    [value, exception, self.class].compact.map(&:hash).inject(:^)
  end

  def raised?
    !exception.nil?
  end
end
