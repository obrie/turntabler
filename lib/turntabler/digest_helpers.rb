module Turntabler
  # Provides a set of helper functions for dealing with message digests
  # @api private
  module DigestHelpers
    # Generates a SHA1 hash from the given data
    # 
    # @param [String] data The data to create a hash from
    # @return [String]
    def digest(data)
      Digest::SHA1.hexdigest(data.to_s)
    end
  end
end
