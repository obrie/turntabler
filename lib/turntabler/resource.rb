require 'pp'
require 'turntabler/assertions'
require 'turntabler/digest_helpers'
require 'turntabler/error'

module Turntabler
  # Represents an object that's been created using content from Turntable. This
  # encapsulates responsibilities such as reading and writing attributes.
  # 
  # By default all Turntable resources have a +:id+ attribute defined.
  class Resource
    include Assertions
    include DigestHelpers

    class << self
      include Assertions

      # Defines a new Turntable attribute on this class.  By default, the name
      # of the attribute is assumed to be the same name that Turntable specifies
      # in its API.  If the names are different, this can be overridden on a
      # per-attribute basis.
      # 
      # @api private
      # @param [String] name The public name for the attribute
      # @param [Hash] options The configuration options
      # @option options [Boolean] :load (true) Whether the resource should be loaded remotely from Turntable in order to access the attribute
      # @raise [ArgumentError] if an invalid option is specified
      # @example
      #   # Define a "name" attribute that maps to a Turntable "name" attribute
      #   attribute :name
      #   
      #   # Define an "id" attribute that maps to a Turntable "_id" attribute
      #   attribute :id, :_id
      #   
      #   # Define an "user_id" attribute that maps to both a Turntable "user_id" and "userid" attribute
      #   attribute :user_id, :user_id, :userid
      #   
      #   # Define a "time" attribute that maps to a Turntable "time" attribute
      #   # and converts the value to a Time object
      #   attribute :time do |value|
      #     Time.at(value)
      #   end
      #   
      #   # Define a "created_at" attribute that maps to a Turntable "time" attribute
      #   # and converts the value to a Time object
      #   attribute :created_at, :time do |value|
      #     Time.at(value)
      #   end
      #   
      #   # Define a "friends" attribute that does *not* get loaded from Turntable
      #   # when accessed
      #   attribute :friends, :load => false
      # 
      # @!macro [attach] attribute
      #   @!attribute [r] $1
      def attribute(name, *turntable_names, &block)
        options = turntable_names.last.is_a?(Hash) ? turntable_names.pop : {}
        assert_valid_keys(options, :load)
        options = {:load => true}.merge(options)

        # Reader
        define_method(name) do
          load if instance_variable_get("@#{name}").nil? && !loaded? && options[:load]
          instance_variable_get("@#{name}")
        end

        # Query
        define_method("#{name}?") do
          !!__send__(name)
        end

        # Typecasting
        block ||= lambda {|value| value}
        define_method("typecast_#{name}", &block)
        protected :"typecast_#{name}"

        # Attribute name conversion
        turntable_names = [name] if turntable_names.empty?
        turntable_names.each do |turntable_name|
          define_method("#{turntable_name}=") do |value|
            instance_variable_set("@#{name}", value.nil? ? nil : __send__("typecast_#{name}", value))
          end
          protected :"#{turntable_name}="
        end
      end
    end

    # The unique identifier for this resource
    # @return [String, Fixnum]
    attribute :id, :_id, :load => false

    # Initializes this resources with the given attributes.  This will continue
    # to call the superclass's constructor with any additional arguments that
    # get specified.
    # 
    # @api private
    def initialize(client, attributes = {}, *args)
      @loaded = false
      @client = client
      self.attributes = attributes
      super(*args)
    end

    # Loads the attributes for this resource from Turntable.  By default this is
    # a no-op and just marks the resource as loaded.
    # 
    # @return [true]
    def load
      @loaded = true
    end
    alias :reload :load

    # Determines whether the current resource has been loaded from Turntable.
    # 
    # @return [Boolean] +true+ if the resource has been loaded, otherwise +false+
    def loaded?
      @loaded
    end

    # Attempts to set attributes on the object only if they've been explicitly
    # defined by the class.  Note that this will also attempt to interpret any
    # "metadata" properties as additional attributes.
    # 
    # @api private
    # @param [Hash] attributes The updated attributes for the resource
    def attributes=(attributes)
      if attributes
        attributes.each do |attribute, value|
          attribute = attribute.to_s
          if attribute == 'metadata'
            self.attributes = value
          else
            __send__("#{attribute}=", value) if respond_to?("#{attribute}=")
          end
        end
      end
    end

    # Forces this object to use PP's implementation of inspection.
    # 
    # @api private
    # @return [String]
    def pretty_print(q)
      q.pp_object(self)
    end
    alias inspect pretty_print_inspect

    # Defines the instance variables that should be printed when inspecting this
    # object.  This ignores the +@client+ and +@loaded+ variables.
    # 
    # @api private
    # @return [Array<Symbol>]
    def pretty_print_instance_variables
      (instance_variables - [:'@client', :'@loaded']).sort
    end

    # Determines whether this resource is equal to another based on their
    # unique identifiers.
    # 
    # @param [Object] other The object this resource is being compared against
    # @return [Boolean] +true+ if the resource ids are equal, otherwise +false+
    def ==(other)
      if other && other.respond_to?(:id) && other.id
        other.id == id
      else
        false
      end
    end
    alias :eql? :==

    # Generates a hash for this resource based on the unique identifier
    # 
    # @return [Fixnum]
    def hash
      id.hash
    end

    private
    # The client that all APIs filter through
    attr_reader :client

    # Runs the given API command on the client.
    def api(command, options = {})
      client.api(command, options)
    end

    # Gets the current room the user is in
    def room
      client.room || raise(APIError, 'User is not currently in a room')
    end
    
    # Determines whether the user is currently in a room
    def room?
      !client.room.nil?
    end
  end
end
