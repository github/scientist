# Internal: What happens when this block gets called?
class Scientist::Observation
  attr_reader :name
  attr_reader :exception
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

  def raised?
    !exception.nil?
  end

  def value
    if raised?
      raise Scientist::NoValue.new(self)
    end

    @value
  end
end
