require "scientist/default"
require "scientist/errors"
require "scientist/experiment"
require "scientist/observation"
require "scientist/result"
require "scientist/version"

module Scientist
  def science(name, run: nil, **options)
    experiment = Experiment.new(name, **options)
    experiment.context(default_scientist_context)

    yield experiment if block_given?
    experiment.run(run)
  end

  def default_scientist_context
    {}
  end
end
