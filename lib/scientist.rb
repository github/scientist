require "scientist/default"
require "scientist/errors"
require "scientist/experiment"
require "scientist/observation"
require "scientist/result"
require "scientist/version"

module Scientist
  def science(*args)
    experiment = Experiment.new(*args)
    yield experiment if block_given?

    experiment.run
  end
end
