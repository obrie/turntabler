require 'turntabler/assertions'
require 'turntabler/event'
require 'turntabler/loggable'

module Turntabler
  # Represents a callback that's been bound to a particular event
  # @api private
  class Handler
    include Assertions
    include Loggable

    # The event this handler is bound to
    # @return [String]
    attr_reader :event

    # Whether to only call the handler once and then never again
    # @return [Boolean] +true+ if only called once, otherwise +false+
    attr_reader :once

    # The data that must be matched in order for the handler to run
    # @return [Hash<String, Object>]
    attr_reader :conditions

    # Builds a new handler bound to the given event.
    # 
    # @param [String] event The name of the event to bind to
    # @param [Hash] options The configuration options
    # @option options [Boolean] :once (false) Whether to only call the handler once
    # @option options [Hash] :if (nil) Data that must be matched to run
    # @raise [ArgumentError] if an invalid option is specified
    def initialize(event, options = {}, &block)
      assert_valid_values(event, *Event.commands.values)
      assert_valid_keys(options, :once, :if)
      options = {:once => false, :if => nil}.merge(options)

      @event = event
      @once = options[:once]
      @conditions = options[:if]
      @block = block
    end

    # Runs this handler for each result from the given event.
    # 
    # @param [Turntabler::Event] event The event being triggered
    # @return [Boolean] +true+ if conditions were matched to run the handler, otherwise +false+
    def run(event)
      if conditions_match?(event.data)
        # Run the block for each individual result
        event.results.each do |args|
          begin
            @block.call(*args)
          rescue StandardError => ex
            logger.error(([ex.message] + ex.backtrace) * "\n")
          end
        end

        true
      else
        false
      end
    end

    private
    # Determines whether the conditions configured for this handler match the
    # event data
    def conditions_match?(data)
      if conditions
        conditions.all? {|(key, value)| data[key] == value}
      else
        true
      end
    end
  end
end
