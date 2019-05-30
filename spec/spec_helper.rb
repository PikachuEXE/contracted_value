# frozen_string_literal: true

if ENV["TRAVIS"]
  require "coveralls"
  Coveralls.wear!
end

require "contracted_value/core"

require "logger"

require "rspec"
require "rspec/its"
