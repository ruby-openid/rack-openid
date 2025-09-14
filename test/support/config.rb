# External dependencies
require "require_bench" if ENV.fetch("REQUIRE_BENCH", "false").casecmp?("true")
require "byebug" if ENV.fetch("DEBUG", "false").casecmp?("true")
require "net/http"
require "rack"
require "rack/session"

# External testing libraries
require "minitest/rg"

# Test support
require_relative "logging"

## Last thing before loading this gem is to setup code coverage
begin
  # This does not require "simplecov", but
  require "kettle-soup-cover"
  #   this next line has a side-effect of running `.simplecov`
  require "simplecov" if defined?(Kettle::Soup::Cover) && Kettle::Soup::Cover::DO_COV
rescue LoadError
  nil
end

# Testing libraries that need to load after simplecov
require "minitest/autorun"
require "minitest/focus"

# rots depends on this library, but the tests here also depend on it,
# so it needs to load after simplecov, in order to get accurate coverage of this gem,
# since this gem is loaded by rots.
require "rots"
require "rots/mocks"
require "rots/test"

OpenID::Util.logger = TestLogging::LOGGER
OpenID.fetcher = Rots::Mocks::Fetcher.new(Rots::Mocks::RotsServer.new)

# This library
require "rack-openid2"
require "rack/openid/simple_auth"
