# Internal: What happens when a block gets called?
class Scientist::Observation
  attr_reader :value
  attr_reader :exception
  attr_reader :duration

  def initialize(&block)

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
end
