require 'logger'
require 'em-synchrony'

# Turntable.FM API for Ruby
module Turntabler
  autoload :Client, 'turntabler/client'

  class << self
    # The logger to use for all Turntable messages.  By default, everything is
    # logged to STDOUT.
    # @return [Logger]
    attr_accessor :logger

    # Whether this is going to be used in an interactive console such as IRB.
    # If this is enabled then EventMachine will run in a separate thread.  This
    # will allow IRB to continue to actually be interactive.
    # 
    # @note You must continue to run all commands on a client through Turntabler#run.
    # @example
    #   require 'turntabler'
    #   
    #   Turntabler.interactive
    #   Turntabler.run do
    #     @client = Turntabler::Client.new(...)
    #     @client.start
    #   end
    #   
    #   # ...later on after the connection has started and you want to interact with it
    #   Turntabler.run do
    #     @client.user.load
    #     # ...
    #   end
    def interactive
      Thread.new { EM.run }.abort_on_exception = true
    end

    # Sets up the proper EventMachine reactor / Fiber to run commands against a
    # client.  If this is not in interactive mode, then the block won't return
    # until the EventMachine reactor is stopped.
    # 
    # @note If you're already running within an EventMachine reactor *and* a
    # Fiber, then there's no need to call this method prior to interacting with
    # a Turntabler::Client instance.
    # @example
    #   # Non-interactive, not in reactor / fiber
    #   Turntabler.run do
    #     client = Turntabler::Client.new(...)
    #     client.room.become_dj
    #     # ...
    #   end
    #   
    #   # Interactive, not in reactor / fiber
    #   Turntabler.run do
    #     client.room.become_dj
    #     # ...
    #   end
    #   
    #   # Non-interactive, already in reactor / fiber
    #   client = Turntabler::Client(...)
    #   client.room.become_dj
    # 
    # @example DSL
    #   # Takes the same arguments as Turntabler::Client
    #   Turntabler.run(USER, AUTH, :room => ROOM) do
    #     room.become_dj
    #     on :user_enter do
    #       # ...
    #     end
    #   end
    # 
    # == Exception handling
    # 
    # Any exceptions that occur within the block will be automatically caught
    # and logged.  This prevents the EventMachine reactor from dying.
    def run(*args, &block)
      if EM.reactor_running?
        EM.next_tick do
          EM.synchrony do
            begin
              if args.any?
                # Run the block within a client
                Client.new(*args, &block)
              else
                # Just run the block within a fiber
                block.call
              end
            rescue Exception => ex
              logger.error(([ex.message] + ex.backtrace) * "\n")
            end
          end
        end
      else
        EM.synchrony { run(*args, &block) }
      end
    end
  end

  @logger = Logger.new(STDOUT)
end

# Provide a simple alias (akin to EM / EventMachine)
TT = Turntabler
