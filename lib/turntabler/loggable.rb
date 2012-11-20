module Turntabler
  # Provides a set of helper methods for logging
  # @api private
  module Loggable
    private
    # Delegates access to the logger to Turntabler.logger
    def logger
      Turntabler.logger
    end
  end
end
