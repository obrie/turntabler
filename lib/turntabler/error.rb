module Turntabler
  # Represents an error within the library
  class Error < StandardError
  end
  
  # Represents an error that occurred while connecting to the Turntable API
  class ConnectionError < Error
  end
  
  # Represents an error that occurred while interacting with the Turntable API
  class APIError < Error
  end
end
