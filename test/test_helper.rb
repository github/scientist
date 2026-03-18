if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-lcov"

  SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
  SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
  SimpleCov.start
end

require "minitest/autorun"

$LOAD_PATH.unshift(File.expand_path(File.join(__dir__, "../lib")))
require "scientist"
