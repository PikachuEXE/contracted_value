# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require "contracted_value"

if ENV["TRAVIS"]
  require "simplecov"
  SimpleCov.start

  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require "rspec"
require "rspec/its"
