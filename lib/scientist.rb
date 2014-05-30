require "scientist/default"
require "scientist/errors"
require "scientist/experiment"
require "scientist/observation"
require "scientist/result"
require "scientist/version"

module Scientist
  def science(*args, &block)
    Scientist.experiment.new(*args, &block).run
  end

  def self.experiment
    @experiment ||= Scientist::Default
  end

  def self.experiment=(klass)
    @experiment = klass
  end
end
