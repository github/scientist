module Scientist
  def science(*args, &block)
    Scientist.experiment.new(*args, &block).run
  end

  class << self
    attr_accessor :experiment

    def reset
      @experiment = Scientist::Default
    end
  end
end

require "scientist/default"
require "scientist/errors"
require "scientist/experiment"
require "scientist/observation"
require "scientist/result"
require "scientist/version"

Scientist.reset
