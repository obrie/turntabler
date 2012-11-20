module Turntabler
  # Provides a set of helper methods for making assertions about the content
  # of various objects
  # @api private
  module Assertions
    # Validates that the given hash *only* includes the specified valid keys.
    #
    # @return [nil]
    # @raise [ArgumentError] if any invalid keys are found
    # @example
    #   options = {:name => 'John Smith', :age => 30}
    #   
    #   assert_valid_keys(options, :name)           # => ArgumentError: Invalid key(s): age
    #   assert_valid_keys(options, 'name', 'age')   # => ArgumentError: Invalid key(s): age, name
    #   assert_valid_keys(options, :name, :age)     # => nil
    def assert_valid_keys(hash, *valid_keys)
      invalid_keys = hash.keys - valid_keys
      raise ArgumentError, "Invalid key(s): #{invalid_keys.join(', ')}" unless invalid_keys.empty?
    end

    # Validates that the given value *only* matches one of the specified valid
    # values.
    #
    # @return [nil]
    # @raise [ArgumentError] if the value is not found
    # @example
    #   value = :age
    #   
    #   assert_valid_values(value, :name)           # => ArgumentError: :age is an invalid value; must be one of: :name
    #   assert_valid_values(value, 'name', 'age')   # => ArgumentError: :age is an invalid value; must be one of: :name, "age"
    #   assert_valid_values(value, :name, :age)     # => nil
    def assert_valid_values(value, *valid_values)
      raise ArgumentError, "#{value} is an invalid value; must be one of: #{valid_values.join(', ')}" unless valid_values.include?(value)
    end
  end
end
