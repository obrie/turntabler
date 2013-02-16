require 'turntabler/room'

module Turntabler
  # Provides a set of helper methods for interacting with Turntable's directory
  # of rooms.
  class RoomDirectory
    include Assertions

    # @api private
    def initialize(client)
      @client = client
    end

    # Creates a new room with the given name and configuration.  This should
    # only be used if the room doesn't already exist.
    # 
    # @note This will automatically enter the room when it is created
    # @param [String] name The name of the room
    # @param [Hash] attributes The initial attributes for the room
    # @option attributes [String] :privacy ("public") TheThe level which the room will be made available to others ("public" or "unlisted")
    # @option attributes [Fixnum] :dj_capacity (5) The maximum number of DJs allowed
    # @option attributes [Fixnum] :dj_minimum_points (0) The minimum number of points required for a user to DJ
    # @return [Turntabler::Room]
    # @raise [ArgumentError] if an invalid attribute is specified
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   rooms.create("Rock Awesomeness")    # => #<Turntabler::Room ...>
    def create(name, attributes = {})
      assert_valid_keys(attributes, :privacy, :dj_capacity, :dj_minimum_points)
      attributes = {:privacy => 'public', :dj_capacity => 5, :dj_minimum_points => 0}.merge(attributes)

      # Convert attribute names over to their Turntable equivalent
      {:dj_capacity => :max_djs, :dj_minimum_points => :djthreshold}.each do |from, to|
        attributes[to] = attributes.delete(from) if attributes[from]
      end

      data = api('room.create', attributes.merge(:room_name => name))
      room = Room.new(client, attributes.merge(:_id => data['roomid'], :shortcut => data['shortcut'], :name => name))
      room.enter
      room
    end

    # Gets the list of available rooms.
    # 
    # @param [Hash] options The search options
    # @option options [Fixnum] :limit (20) The total number of rooms to list
    # @option options [Fixnum] :skip (0) The number of rooms to skip when loading the list
    # @option options [Fixnum] :favorites (false) Whether to only include rooms marked as favorites
    # @option options [Boolean] :available_djs (false) Whether to only include rooms that have dj spots available
    # @option options [Symbol] :genre The genre of music being played in the room, .  Possible values are +:rock+, +:electronica+, +:indie+, +:hiphop+, +:pop+, and +:dubstep+.
    # @option options [Fixnum] :minimum_listeners (1) The minimum number of listeners in the room
    # @option options [Symbol] :sort (:listeners) The order to list rooms in.  Possible values are +:created+, +:listeners+, and +:random+.
    # @return [Array<Turntabler::Room>]
    # @raise [ArgumentError] if an invalid option or value is specified
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   rooms.all                                           # => [#<Turntabler::Room ...>, ...]
    #   rooms.all(:favorites => true)                       # => [#<Turntabler::Room ...>, ...]
    #   rooms.all(:available_djs => true, :genre => :rock)  # => [#<Turntabler::Room ...>, ...]
    #   rooms.all(:sort => :random)                         # => [#<Turntabler::Room ...>, ...]
    def all(options = {})
      assert_valid_keys(options, :limit, :skip, :favorites, :available_djs, :genre, :minimum_listeners, :sort)
      assert_valid_values(options[:genre], :rock, :electronic, :indie, :hiphop, :pop, :dubstep) if options[:genre]
      assert_valid_values(options[:sort], :created, :listeners, :random) if options[:sort]
      options = {
        :limit => 20,
        :skip => 0,
        :favorites => false,
        :available_djs => false,
        :minimum_listeners => 1,
        :sort => :listeners
      }.merge(options)

      constraints = []
      constraints << :favorites if options[:favorites]
      constraints << :available_djs if options[:available_djs]
      constraints << :"has_people=#{options[:minimum_listeners]}"
      if options[:genre]
        constraints << :"genre=#{options[:genre]}"
        options[:sort] = "#{options[:sort]},genre:#{options[:genre]}"
      end

      data = api('room.directory_rooms',
        :section_aware => true,
        :limit => options[:limit],
        :skip => options[:skip],
        :constraints => constraints * ',',
        :sort => options[:sort]
      )
      data['rooms'].map {|attrs| Room.new(client, attrs)}
    end

    # Gets the rooms where the current user's friends are currently listening.
    # 
    # @return [Array<Turntabler::Room>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #  rooms.with_friends   # => [#<Turntabler::Room ...>, ...]
    def with_friends
      data = api('room.directory_graph')
      data['rooms'].map do |(attrs, friends)|
        Room.new(client, attrs.merge(:friends => friends))
      end
    end

    # Finds rooms that match the given query string.
    # 
    # @param [String] query The query string to search with
    # @param [Hash] options The search options
    # @option options [Fixnum] :limit (20) The maximum number of rooms to query for
    # @option options [Fixnum] :skip (0) The number of rooms to skip when loading the results
    # @return [Array<Turntabler::Room>]
    # @raise [ArgumentError] if an invalid option is specified
    # @raise [Turntabler::Error] if the command fails
    #   rooms.find('indie')   # => [#<Turntabler::Room ...>, ...]
    def find(query, options = {})
      assert_valid_keys(options, :limit, :skip)
      options = {:limit => 20, :skip => 0}.merge(options)

      data = api('room.search', :query => query, :skip => options[:skip])
      data['rooms'].map {|(attrs, *)| Room.new(client, attrs)}
    end

    private
    # The client that all APIs filter through
    attr_reader :client

    # Runs the given API command on the client.
    def api(command, options = {})
      client.api(command, options)
    end
  end
end
