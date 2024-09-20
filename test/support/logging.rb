require "logger"

module TestLogging
  LOGGER = Logger.new($stdout)
end

TestLogging::LOGGER.level = Logger::WARN
