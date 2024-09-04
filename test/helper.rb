require "minitest/autorun"
require "minitest/rg"
require "net/http"

require "rack"
require "rack/session"
require "rack/openid"
require "rack/openid/simple_auth"

log = Logger.new($stdout)
log.level = Logger::WARN
OpenID::Util.logger = log
