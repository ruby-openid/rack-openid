# External dependencies
require "byebug" if ENV.fetch("DEBUG", "false").casecmp?("true")
require "net/http"
require "rack"
require "rack/session"

# testing libraries
require "minitest/rg"

# Test support
require "support/logging"

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

# Internal dependencies & mixins
require "rack/openid"
require "rack/openid/simple_auth"

OpenID::Util.logger = TestLogging::LOGGER
