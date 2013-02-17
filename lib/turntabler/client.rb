require 'fiber'

require 'turntabler/authorized_user'
require 'turntabler/avatar'
require 'turntabler/connection'
require 'turntabler/error'
require 'turntabler/event'
require 'turntabler/handler'
require 'turntabler/loggable'
require 'turntabler/room_directory'
require 'turntabler/song'
require 'turntabler/sticker'
require 'turntabler/user'

module Turntabler
  # Provides access to the Turntable API
  class Client
    include Assertions
    include DigestHelpers
    include Loggable

    # The unique id representing this client
    # @return [String]
    attr_reader :id

    # Sets the current room the user is in
    # @api private
    # @param [Turntabler::Room] value The new room
    attr_writer :room

    # The directory for looking up / creating rooms
    # @return [Turntabler::RoomDirectory]
    attr_reader :rooms

    # The response timeout configured for the connection
    # @return [Fixnum]
    attr_reader :timeout
    
    # Creates a new client for communicating with Turntable.fm with the given
    # email / password.
    # 
    # @param [String] email The e-mail address of the user to authenticate with
    # @param [String] password The Turntable password associated with the email address
    # @param [Hash] options The configuration options for the client
    # @option options [String] :id The unique identifier representing this client
    # @option options [String] :room The id of the room to initially enter
    # @option options [String] :user_id The Turntable id for the authenticating user (required if the user does not have an associated password)
    # @option options [String] :auth The authentication token for the user (required if the user does not have an associated password)
    # @option options [Fixnum] :timeout (10) The amount of seconds to allow to elapse for requests before timing out
    # @option options [Boolean] :reconnect (false) Whether to allow the client to automatically reconnect when disconnected either by Turntable or by the network
    # @option options [Fixnum] :reconnect_wait (5) The amount of seconds to wait before reconnecting
    # @raise [Turntabler::Error] if an invalid option is specified
    # @yield Runs the given block within the context if the client (for DSL-type usage)
    def initialize(email, password, options = {}, &block)
      options = {
        :id => "#{Time.now.to_i}-#{rand}",
        :timeout => 10,
        :reconnect => false,
        :reconnect_wait => 5
      }.merge(options)
      assert_valid_keys(options, :id, :room, :url, :user_id, :auth, :timeout, :reconnect, :reconnect_wait)

      @id = options[:id]
      @user = AuthorizedUser.new(self, :email => email, :password => password, :_id => options[:user_id], :userauth => options[:auth])
      @rooms = RoomDirectory.new(self)
      @event_handlers = {}
      @timeout = options[:timeout]
      @reconnect = options[:reconnect]
      @reconnect_wait = options[:reconnect_wait]

      # Setup default event handlers
      on(:heartbeat) { on_heartbeat }
      on(:session_missing) { on_session_missing }
      on(:session_ended) { on_session_ended }

      # Connect to an initial room / server
      reconnect_from(ConnectionError, APIError) do
        if room_name = options[:room]
          room(room_name).enter
        elsif url = options[:url]
          connect(url)
        else
          connect
        end
      end

      instance_eval(&block) if block_given?
    end

    # Initiates a connection with the given url.  Once a connection is started,
    # this will also attempt to authenticate the user.
    # 
    # @api private
    # @note This will only open a new connection if the client isn't already connected to the given url
    # @param [String] url The url to open a connection to
    # @return [true]
    # @raise [Turntabler::Error] if the connection cannot be opened
    def connect(url = room(digest(rand)).url)
      if !@connection || !@connection.connected? || @connection.url != url
        # Close any existing connection
        close

        # Create a new connection to the given url
        @connection = Connection.new(url, :timeout => timeout, :params => {:clientid => id, :userid => user.id, :userauth => user.auth})
        @connection.handler = lambda {|data| trigger(data.delete('command'), data)}
        @connection.start

        # Wait until the connection is authenticated
        wait do |&resume|
          on(:session_missing, :once => true) { resume.call }
        end
      end

      true
    end

    # Closes the current connection to Turntable if one was previously opened.
    # 
    # @return [true]
    def close(allow_reconnect = false)
      if @connection
        # Disable reconnects if specified
        reconnect = @reconnect
        @reconnect = reconnect && allow_reconnect

        # Clean up timers / connections
        @keepalive_timer.cancel if @keepalive_timer
        @keepalive_timer = nil
        @connection.close

        # Revert change to reconnect config once the final signal is received
        wait do |&resume|
          on(:session_ended, :once => true) { resume.call }
        end
        @reconnect = reconnect
      end
      
      true
    end

    # Gets the chat server url currently connected to
    # 
    # @api private
    # @return [String]
    def url
      @connection && @connection.url
    end

    # Runs the given API command.
    # 
    # @api private
    # @param [String] command The name of the command to execute
    # @param [Hash] params The parameters to pass into the command
    # @return [Hash] The data returned from the Turntable service
    # @raise [Turntabler::Error] if the connection is not open or the command fails to execute
    def api(command, params = {})
      raise(ConnectionError, 'Connection is not open') unless @connection && @connection.connected?
      
      message_id = @connection.publish(params.merge(:api => command))

      # Wait until we get a response for the given message
      data = wait do |&resume|
        on(:response_received, :once => true, :if => {'msgid' => message_id}) {|data| resume.call(data)}
      end

      if data['success']
        data
      else
        error = data['error'] || data['err']
        raise APIError, "Command \"#{command}\" failed with message: \"#{error}\""
      end
    end

    # Registers a handler to invoke when an event occurs in Turntable.
    # 
    # @param [Symbol] event The event to register a handler for
    # @param [Hash] options The configuration options for the handler
    # @option options [Hash] :if Specifies a set of key-value pairs that must be matched in the event data in order to run the handler
    # @option options [Boolean] :once (false) Whether to only run the handler once
    # @return [true]
    # 
    # == Client Events
    # 
    # * +:reconnected+ - The client reconnected (and re-entered any room that the user was previously in)
    # 
    # @example
    #   client.on :reconnected do
    #     client.room.dj
    #     # ...
    #   end
    # 
    # == Room Events
    # 
    # * +:room_updated+ - Information about the room was updated
    # 
    # @example
    #   client.on :room_updated do |room| # Room
    #     puts room.description
    #     # ...
    #   end
    # 
    # == User Events
    # 
    # * +:user_entered+ - A user entered the room
    # * +:user_left+ - A user left the room
    # * +:user_booted+ - A user has been booted from the room
    # * +:user_updated+ - A user's name / profile was updated
    # * +:user_spoke+ - A user spoke in the chat room
    # 
    # @example
    #   client.on :user_entered do |user| # User
    #     puts user.id
    #     # ...
    #   end
    #   
    #   client.on :user_left do |user| # User
    #     puts user.id
    #     # ...
    #   end
    #   
    #   client.on :user_booted do |boot| # Boot
    #     puts boot.user.id
    #     puts boot.reason
    #     # ...
    #   end
    #   
    #   client.on :user_updated do |user| # User
    #     puts user.laptop_name
    #     # ...
    #   end
    #   
    #   client.on :user_spoke do |message| # Message
    #    puts message.content
    #     # ...
    #   end
    #   
    # == DJ Events
    # 
    # * +:dj_added+ - A new DJ was added to the booth
    # * +:dj_removed+ - A DJ was removed from the booth
    # 
    # @example
    #   client.on :dj_added do |user| # User
    #     puts user.id
    #     # ...
    #   end
    #   
    #   client.on :dj_removed do |user| # User
    #     puts user.id
    #     # ...
    #   end
    # 
    # == Moderator Events
    # 
    # * +:moderator_added+ - A new moderator was added to the room
    # * +:moderator_removed+ - A moderator was removed from the room
    # 
    # @example
    #   client.on :moderator_added do |user| # User
    #     puts user.id
    #     # ...
    #   end
    #   
    #   client.on :moderator_removed do |user| # User
    #     puts user.id
    #     # ...
    #   end
    # 
    # == Song Events
    # 
    # * +:song_unavailable+ - Indicates that there are no more songs to play in the room
    # * +:song_started+ - A new song has started playing
    # * +:song_ended+ - The current song has ended.  This is typically followed by a +:song_started+ or +:song_unavailable+ event.
    # * +:song_voted+ - One or more votes were cast for the song
    # * +:song_snagged+ - A user in the room has queued the current song onto their playlist
    # * +:song_blocked+ - A song was skipped due to a copyright claim
    # * +:song_limited+ - A song was skipped due to a limit on # of plays per hour
    # 
    # @example
    #   client.on :song_unavailable do
    #     # ...
    #   end
    #   
    #   client.on :song_started do |song| # Song
    #     puts song.title
    #     # ...
    #   end
    #   
    #   client.on :song_ended do |song| # Song
    #     puts song.title
    #     # ...
    #   end
    #   
    #   client.on :song_voted do |song| # Song
    #     puts song.up_votes_count
    #     puts song.down_votes_count
    #     puts song.votes
    #     # ...
    #   end
    #   
    #   client.on :song_snagged do |snag| # Snag
    #     puts snag.user.id
    #     puts snag.song.id
    #     # ...
    #   end
    #   
    #   client.on :song_blocked do |song| # Song
    #     puts song.id
    #     # ...
    #   end
    #   
    #   client.on :song_limited do |song| # Song
    #     puts song.id
    #     # ...
    #   end
    # 
    # == Messaging Events
    # 
    # * +:message_received+ - A private message was received from another user in the room
    # 
    # @example
    #   client.on :message_received do |message| # Message
    #     puts message.content
    #     # ...
    #   end
    def on(event, options = {}, &block)
      event = event.to_sym
      @event_handlers[event] ||= []
      @event_handlers[event] << Handler.new(event, options, &block)
      true
    end

    # Gets the current room the authorized user is in or builds a new room
    # bound to the given room id.
    # 
    # @param [String] room_id The id of the room to build
    # @return [Turntabler::Room]
    # @example
    #   client.room               # => #<Turntabler::Room id="ab28f..." ...>
    #   client.room('50985...')   # => #<Turntabler::Room id="50985..." ...>
    def room(room_id = nil)
      room_id ? Room.new(self, :_id => room_id) : @room
    end

    # Gets the current authorized user or builds a new user bound to the given
    # user id.
    # 
    # @param [String] user_id The id of the user to build
    # @return [Turntabler::User]
    # @example
    #   client.user               # => #<Turntabler::User id="fb129..." ...>
    #   client.user('a34bd...')   # => #<Turntabler::User id="a34bd..." ...>
    def user(user_id = nil)
      user_id ? User.new(self, :_id => user_id) : @user
    end

    # Gets the user with the given DJ name.  This should only be used if the id
    # of the user is unknown.
    # 
    # @param [String] name The user's DJ name
    # @return [Turntabler::User]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   client.user_by_name('DJSpinster')   # => #<Turntabler::User id="a34bd..." ...>
    def user_by_name(name)
      data = api('user.get_id', :name => name)
      user = self.user(data['userid'])
      user.attributes = {'name' => name}
      user
    end

    # Get all avatars availble on Turntable.
    # 
    # @return [Array<Turntabler::Avatar>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   client.avatars    # => [#<Turntabler::Avatar ...>, ...]
    def avatars
      data = api('user.available_avatars')
      avatars = []
      data['avatars'].each do |avatar_group|
        avatar_group['avatarids'].each do |avatar_id|
          avatars << Avatar.new(self, :_id => avatar_id, :min => avatar_group['min'], :acl => avatar_group['acl'])
        end
      end
      avatars
    end

    # Get all stickers available on Turntable.
    # 
    # @return [Array<Turntabler::Sticker>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   client.stickers   # => [#<Turntabler::Sticker id="...">, ...]
    def stickers
      data = api('sticker.get')
      data['stickers'].map {|attrs| Sticker.new(self, attrs)}
    end

    # Builds a new song bound to the given song id.
    # 
    # @param [String] song_id The id of the song to build
    # @return [Turntabler::Song]
    # @example
    #   client.song('a34bd...')   # => #<Turntabler::Song id="a34bd..." ...>
    def song(song_id)
      Song.new(self, :_id => song_id)
    end

    # Finds songs that match the given query.
    # 
    # @note The user must be entered in a room to search for songs
    # @param [String] query The query string to search for.  This should just be the title of the song if :artist is specified.
    # @param [Hash] options The configuration options for the search
    # @option options [String] :artist The name of the artist for the song
    # @option options [Fixnum] :duration The length, in minutes, of the song
    # @option options [Fixnum] :page The page number to get from the results
    # @return [Array<Turntabler::Song>]
    # @raise [ArgumentError] if an invalid option is specified
    # @raise [Turntabler::Error] if the user is not in a room or the command fails
    # @example
    #   # Less accurate, general query search
    #   client.search_song('Like a Rolling Stone by Bob Dylan')             # => [#<Turntabler::Song ...>, ...]
    #   
    #   # More accurate, explicit title / artist search
    #   client.search_song('Like a Rolling Stone', :artist => 'Bob Dylan')  # => [#<Turntabler::Song ...>, ...]
    def search_song(query, options = {})
      assert_valid_keys(options, :artist, :duration, :page)
      options = {:page => 1}.merge(options)

      raise(APIError, 'User must be in a room to search for songs') unless room

      if artist = options[:artist]
        query = "title: #{query}"
        query << " artist: #{artist}"
      end
      query << " duration: #{options[:duration]}" if options[:duration]

      api('file.search', :query => query, :page => options[:page])

      # Wait for the async callback
      songs = wait do |&resume|
        on(:search_completed, :once => true, :if => {'query' => query}) {|songs| resume.call(songs)}
        on(:search_failed, :once => true, :if => {'query' => query}) { resume.call }
      end

      songs || raise(APIError, 'Search failed to complete')
    end

    # Triggers callback handlers for the given Turntable command.  This should
    # either be invoked when responses are received for Turntable or when
    # triggering custom events.
    # 
    # @note If the command is unknown, it will simply get skipped and not raise an exception
    # @param [Symbol] command The name of the command triggered.  This is typically the same name as the event.
    # @param [Array] args The arguments to be processed by the event
    # @return [true]
    # 
    # == Triggering custom events
    # 
    # After defining custom events, `trigger` can be used to invoke any handler
    # that's been registered for that event.  The argument list passed into
    # `trigger` will be passed, exactly as specified, to the registered
    # handlers.
    # 
    # @example
    #   # Define names of events
    #   Turntabler.events(:no_args, :one_arg, :multiple_args)
    #   
    #   # ...
    #   
    #   # Register handlers
    #   client.on(:no_args) { }
    #   client.on(:one_arg) {|arg| }
    #   client.on(:multiple_args) {|arg1, arg2| }
    #   
    #   # Trigger handlers registered for events
    #   client.trigger(:no_args)              # => true
    #   client.trigger(:one_arg, 1)           # => true
    #   client.trigger(:multiple_args, 1, 2)  # => true
    def trigger(command, *args)
      command = command.to_sym if command

      if Event.command?(command)
        event = Event.new(self, command, args)
        handlers = @event_handlers[event.name] || []
        handlers.each do |handler|
          success = handler.run(event)
          handlers.delete(handler) if success && handler.once
        end
      end

      true
    end
    
    # Resets the keepalive timer to run at the given interval.
    # 
    # @param [Fixnum] interval The frequency with which keepalives get sent (in seconds)
    # @api private
    def reset_keepalive(interval = 10)
      if !@keepalive_timer || @keepalive_interval != interval
        @keepalive_interval = interval

        # Periodically update the user's status to remain available
        @keepalive_timer.cancel if @keepalive_timer
        @keepalive_timer = EM::Synchrony.add_periodic_timer(interval) do
          Turntabler.run { user.update(:status => user.status) }
        end
      end
    end
    
    private
    # Callback when a heartbeat message has been received from Turntable determining
    # whether this client is still alive.
    def on_heartbeat
      user.update(:status => user.status)
    end
    
    # Callback when session authentication is missing from the connection.  This
    # will automatically authenticate with configured user as well as set up a
    # heartbeat.
    def on_session_missing
      user.authenticate
      user.fan_of
      user.update(:status => user.status)
      reset_keepalive
    end
    
    # Callback when the session has ended.  This will automatically reconnect if
    # allowed to do so.
    def on_session_ended
      url = @connection.url
      room = @room
      @connection = nil
      @room = nil

      # Automatically reconnect to the room / server if allowed
      if @reconnect
        reconnect_from(Exception) do
          room ? room.enter : connect(url)
          trigger(:reconnected)
        end
      end
    end
    
    # Runs a given block and retries that block after a certain period of time
    # if any of the specified exceptions are raised.  Note that there is no
    # limit on the number of attempts to retry.
    def reconnect_from(*exceptions)
      begin
        yield
      rescue *exceptions => ex
        if @reconnect
          logger.debug "Connection failed: #{ex.message}"
          EM::Synchrony.sleep(@reconnect_wait)
          logger.debug 'Attempting to reconnect'
          retry
        else
          raise
        end
      end
    end

    # Pauses the current fiber until it is resumed with response data.  This
    # can only get resumed explicitly by the provided block.
    def wait(&block)
      fiber = Fiber.current

      # Resume the fiber when a response is received
      allow_resume = true
      block.call do |*args|
        fiber.resume(*args) if allow_resume
      end

      # Attempt to pause the fiber until a response is received
      begin
        Fiber.yield
      rescue FiberError => ex
        allow_resume = false
        raise Error, 'Turntabler APIs cannot be called from root fiber; use Turntabler.run { ... } instead'
      end
    end
  end
end
