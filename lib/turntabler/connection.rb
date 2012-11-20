require 'faye/websocket'
require 'em-http'
require 'json'

require 'turntabler/assertions'
require 'turntabler/loggable'

module Turntabler
  # Represents the interface for sending and receiving data in Turntable
  # @api private
  class Connection
    include Assertions
    include Loggable

    # Tracks the list of APIs that don't work through the web socket -- these
    # must be requested through the HTTP channel
    # @return [Array<String>]
    HTTP_APIS = %w(room.directory_rooms user.get_prefs)

    # The URL that this connection is bound to
    # @return [String]
    attr_reader :url

    # The callback to run when a message is received from the underlying socket.
    # The data passed to the callback will always be a hash.
    # @return [Proc]
    attr_accessor :handler

    # Builds a new connection for sending / receiving data via the given url.
    # 
    # @note This will *not* open the connection -- #start must be explicitly called in order to do so.
    # @param [String] url The URL to open a conection to
    # @param [Hash] options The connection options
    # @option options [Fixnum] :timeout The amount of time to allow to elapse for requests before timing out
    # @option options [Hash] :params A default set of params that will get included on every message sent
    # @raise [ArgumentError] if an invalid option is specified
    def initialize(url, options = {})
      assert_valid_keys(options, :timeout, :params)

      @url = url
      @message_id = 0
      @timeout = options[:timeout]
      @default_params = options[:params] || {}
    end

    # Initiates the connection with turntable
    # 
    # @return [true]
    def start
      @socket = Faye::WebSocket::Client.new(url)
      @socket.onopen = lambda {|event| on_open(event)}
      @socket.onclose = lambda {|event| on_close(event)}
      @socket.onmessage = lambda {|event| on_message(event)}
      true
    end

    # Closes the connection (if one was previously opened)
    # 
    # @return [true]
    def close
      @socket.close if @socket
      true
    end

    # Whether this connection's socket is currently open
    # 
    # @return [Boolean] +true+ if the connection is open, otherwise +false+
    def connected?
      @connected
    end

    # Publishes the given params to the underlying web socket.  The defaults
    # initially configured as part of the connection will also be included in
    # the message.
    # 
    # @param [Hash] params The parameters to include in the message sent
    # @return [Fixnum] The id of the message delivered
    def publish(params)
      params[:msgid] = message_id = next_message_id
      params = @default_params.merge(params)
      
      logger.debug "Message sent: #{params.inspect}"

      if HTTP_APIS.include?(params[:api])
        publish_to_http(params)
      else
        publish_to_socket(params)
      end
      
      # Add timeout handler
      EventMachine.add_timer(@timeout) do
        dispatch('msgid' => message_id, 'command' => 'response_received', 'error' => 'timed out')
      end if @timeout

      message_id
    end

    private
    # Publishes the given params to the web socket
    def publish_to_socket(params)
      message = params.to_json
      data = "~m~#{message.length}~m~#{message}"
      @socket.send(data)
    end
    
    # Publishes the given params to the HTTP API
    def publish_to_http(params)
      api = params.delete(:api)
      message_id = params[:msgid]

      http = EventMachine::HttpRequest.new("http://turntable.fm/api/#{api}").get(:query => params)
      if http.response_header.status == 200
        # Command executed properly: parse the results
        success, data = JSON.parse(http.response)
        data = {'result' => data} unless data.is_a?(Hash)
        message = data.merge('success' => success)
      else
        # Command failed to run
        message = {'success' => false, 'error' => http.error}
      end
      message.merge!('msgid' => message_id)

      # Run the message handler
      event = Faye::WebSocket::API::Event.new('message', :data => "~m~#{Time.now.to_i}~m~#{JSON.generate(message)}")
      on_message(event)
    end
    
    # Runs the configured handler with the given message
    def dispatch(message)
      Turntabler.run { @handler.call(message) } if @handler
    end

    # Callback when the socket is opened.
    def on_open(event)
      logger.debug 'Socket opened'
      @connected = true
    end

    # Callback when the socket is closed.  This will mark the connection as no
    # longer connected.
    def on_close(event)
      logger.debug 'Socket closed'
      @connected = false
      @socket = nil
      dispatch('command' => 'session_ended')
    end

    # Callback when a message has been received from the remote server on the
    # open socket.
    def on_message(event)
      data = event.data

      response = data.match(/~m~\d*~m~(.*)/)[1]
      message =
        case response
        when /no_session/
          {'command' => 'no_session'}
        when /~h~([0-9]+)/
          # Send the heartbeat command back to the server
          @socket.send($1)
          {'command' => 'heartbeat'}
        else
          JSON.parse(response)
        end
      message['command'] = 'response_received' if message['msgid']

      logger.debug "Message received: #{message.inspect}"
      dispatch(message)
    end

    # Calculates what the next message id should be sent to turntable
    def next_message_id
      @message_id += 1
    end
  end
end
