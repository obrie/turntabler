require 'set'
require 'em-synchrony/em-http'
require 'turntabler/resource'

module Turntabler
  # Represents an individual room in Turntable.  The room must be explicitly
  # entered before being able to DJ.
  class Room < Resource
    # Allow the id to be set via the "roomid" attribute
    # @return [String]
    attribute :id, :roomid, :load => false

    # The section of the room that the user is in.  This only applies to
    # overflow rooms.
    # @return [String]
    attribute :section, :load => false

    # The human-readable name for the room
    # @return [String]
    attribute :name

    # A longer description of the room (sometimes includes rules, guidelines, etc.)
    # @return [String]
    attribute :description

    # The path which can be used in the url to load the room
    # @return [String]
    attribute :shortcut

    # The privacy level for the room (either "public" or "unlisted")
    # @return [String]
    attribute :privacy

    # The maximum number of listeners that can be in the room (including DJs)
    # @return [Fixnum]
    attribute :listener_capacity, :max_size

    # The maximum number of users that can DJ
    # @return [Fixnum]
    attribute :dj_capacity, :max_djs

    # The minimum number of points required to DJ
    # @return [Fixnum]
    attribute :dj_minimum_points, :djthreshold

    # The type of music being played in the room
    # @return [String]
    attribute :genre

    # The time at which this room was created
    # @return [Time]
    attribute :created_at, :created do |value|
      Time.at(value)
    end

    # The host to connect to for joining this room
    # @return [String]
    attribute :host, :chatserver do |value|
      value[0]
    end

    # Whether this room is being featured by Turntable
    # @return [Boolean]
    attribute :featured

    # The user that created the room
    # @return [Turntabler::User]
    attribute :creator do |attrs|
      build_user(attrs)
    end

    # The listeners currently in the rom
    # @return [Array<Turntabler::User>]
    attribute :listeners, :users do |users|
      Set.new(users.map {|attrs| build_user(attrs)})
    end

    # The users that are currently DJ'ing in the room
    # @return [Array<Turntabler::User>]
    attribute :djs do |ids|
      Set.new(ids.map {|id| build_user(:_id => id)})
    end

    # The users that are appointed to moderate the room
    # @return [Array<Turntabler::User>]
    attribute :moderators, :moderator_id do |ids|
      Set.new(ids.map {|id| build_user(:_id => id)})
    end
    
    # The current user's friends who are also known to be in the room.  These
    # friends must be connected through a separate network like Facebook or Twitter.
    # 
    # @note This is only available when the room is discovered via Turntabler::RoomDirectory#with_friends
    # @return [Array<Turntabler::User>]
    attribute :friends, :load => false do |users|
      Set.new(users.map {|attrs| build_user(attrs)})
    end

    # The current song being played
    # @return [Turntabler::Song]
    attribute :current_song do |attrs|
      Song.new(client, attrs)
    end

    # The current DJ playing
    # @return [Turntabler::User]
    attribute :current_dj do |id|
      build_user(:_id => id)
    end

    # The list of songs that have been played in this room.
    # @note This is not an exhaustive list
    # @return [Array<Turntabler::Song>]
    attribute :songs_played, :songlog, :load => false do |songs|
      songs.map {|attrs| Song.new(client, attrs)}
    end

    # @api private
    def initialize(*)
      @friends = Set.new
      @songs_played = []
      super
    end

    # Uses the configured chat host or attempts to look it up based on the room id
    # 
    # @return [String]
    # @raise [Turntabler::Error] if the host lookup fails
    def host
      @host ||= begin
        response = EventMachine::HttpRequest.new("http://turntable.fm/api/room.which_chatserver?roomid=#{id}").get.response
        JSON.parse(response)[1]['chatserver'][0]
      end
    end

    # Gets the configured chat url
    # 
    # @return [String]
    def url
      "ws://#{host}/socket.io/websocket"
    end

    # Loads the attributes for this room.  Attributes will automatically load
    # when accessed, but this allows data to be forcefully loaded upfront.
    # 
    # @note This will open a connection to the chat server the room is hosted on if the client is not already connected to it
    # @param [Hash] options The configuration options
    # @option options [Boolean] :song_log (false) Whether to include the song log
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.load                       # => true
    #   room.load(:song_log => true)    # => true
    def load(options = {})
      assert_valid_keys(options, :song_log)
      options = {:song_log => false}.merge(options)

      # Use a client that is connected on the same url this room is hosted on
      client = @client.url == url ? @client : Turntabler::Client.new(@client.user.id, @client.user.auth, :url => url, :timeout => @client.timeout)

      begin
        data = client.api('room.info', :roomid => id, :section => section, :extended => options[:song_log])
        self.attributes = data['room'].merge('users' => data['users'])
        super()
      ensure
        # Close the client if it was only opened for use in this API call
        client.close if client != @client
      end
    end

    # Sets the current attributes for this room, ensures that the full list of
    # listeners gets set first so that we can use those built users to then fill
    # out the collection of djs, moderators, etc.
    # 
    # @api private
    def attributes=(attrs)
      if attrs
        super('users' => attrs.delete('users')) if attrs['users']
        super
        
        # Set room-level attributes that are specific to the song
        song_attributes = attrs['metadata'] && attrs['metadata'].select {|key, value| %w(upvotes downvotes votelog).include?(key)}
        current_song.attributes = song_attributes if @current_song
      end
    end

    # Updates this room's information.
    # 
    # @param [Hash] attributes The attributes to update
    # @option attributes [String] :description
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.update(:description => '...')    # => true
    def update(attributes = {})
      assert_valid_keys(attributes, :description)

      api('room.modify', attributes)
      self.attributes = attributes
      true
    end

    # Enters the current room.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.enter    # => true
    def enter
      if client.room != self
        # Leave the old room
        client.room.leave if client.room
        
        # Connect and register with this room
        client.connect(url)
        begin
          client.room = self
          data = api('room.register', :roomid => id, :section => nil)
          self.attributes = {'section' => data['section']}
        rescue Exception
          client.room = nil
          raise
        end
      end
      
      true
    end

    # Leaves from the current room.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.leave    # => true
    def leave
      api('room.deregister', :roomid => id, :section => section)
      true
    end

    # Add this room to the current user's favorites.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.add_as_favorite    # => true
    def add_as_favorite
      api('room.add_favorite', :roomid => id, :section => section)
      true
    end

    # Remove this room from current user's favorites.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.remove_as_favorite   # => true
    def remove_as_favorite
      api('room.rem_favorite', :roomid => id, :section => section)
      true
    end

    # Gets the user represented by the given attributes.  This can either pull
    # the user from:
    # * The currently authorized user
    # * The room's creator
    # * The room's listeners
    # * The room's moderators
    # 
    # If the user isn't present in any of those, then a new User instance will
    # get created.
    # 
    # @api private
    def build_user(attrs)
      user = User.new(client, attrs)
      user = if client.user == user
        client.user
      elsif @creator == user
        creator
      elsif result = @listeners && listener(user.id) || @moderators && moderator(user.id) || friend(user.id)
        result
      else
        user
      end
      user.attributes = attrs
      user
    end

    # Determines whether the current user can dj based on the minimum points
    # required and spot availability
    def can_dj?
      dj_capacity > djs.length && dj_minimum_points <= client.user.points
    end

    # Adds the current user to the list of DJs.
    # 
    # @note This will cause the user to enter the current room if that isn't already the case
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.become_dj    # => true
    def become_dj
      enter
      api('room.add_dj', :roomid => id, :section => section)
      true
    end

    # Gets the dj with the given user id.
    # 
    # @return [Turntabler::User, nil]
    # @example
    #   room.dj('4fd8...')    # => #<Turntabler::User ...>
    def dj(user_id)
      djs.detect {|dj| dj.id == user_id}
    end

    # Gets the listener with the given user id.
    # 
    # @return [Turntabler::User, nil]
    # @example
    #   room.listener('4fd8...')    # => #<Turntabler::User ...>
    def listener(user_id)
      listeners.detect {|listener| listener.id == user_id}
    end

    # Gets the moderator with the given user id.
    # 
    # @return [Turntabler::User, nil]
    # @example
    #   room.moderator('4fd8...')   # => #<Turntabler::User ...>
    def moderator(user_id)
      moderators.detect {|moderator| moderator.id == user_id}
    end

    # Gets the friend in the room with the given user id.
    # 
    # @note This is only available when the room is discovered via Turntabler::RoomDirectory#with_friends
    # @return [Turntabler::User, nil]
    # @example
    #   room.friend('4fd8...')    # => #<Turntabler::User ...>
    def friend(user_id)
      friends.detect {|friend| friend.id == user_id}
    end

    # Braodcasts a message in the chat.
    # 
    # @param [String] text The text to send to the chat
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.say("What's up guys?")   # => true
    def say(text)
      enter
      api('room.speak', :text => text)
      true
    end

    # Reports abuse by a room.
    # 
    # @param [String] reason The reason the room is being reported
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   room.report('Name abuse ...')   # => true
    def report(reason = '')
      api('room.report', :roomid => id, :section => section, :reason => reason)
      true
    end
    
    private
    # Sets the sticker placements for each dj
    def sticker_placements=(user_placements)
      user_placements.each do |user_id, placements|
        listener(user_id).attributes = {'placements' => placements}
      end
    end
  end
end
