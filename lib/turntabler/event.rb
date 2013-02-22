require 'turntabler/boot'
require 'turntabler/message'
require 'turntabler/snag'
require 'turntabler/song'

module Turntabler
  # Provides access to all of the events that get triggered by incoming messages
  # from the Turntable API
  # @api private
  class Event
    class << self
      # Maps Turntable command => event name
      # @return [Hash<String, String>]
      attr_reader :commands

      # Defines a new event that maps to the given Turntable command.  The
      # block defines how to typecast the data that is received from Turntable.
      # 
      # @param [String] name The name of the event exposed to the rest of the library
      # @param [String] command The Turntable command that this event name maps to
      # @yield [data] Gives the data to typecast to the block
      # @yieldparam [Hash] data The data received from Turntable
      # @yieldreturn The typecasted data that should be passed into any handlers bound to the event
      # @return [nil]
      def handle(name, command = name, &block)
        block ||= lambda { [args] }
        commands[command] = name

        define_method("typecast_#{command}_event", &block)
        protected :"typecast_#{command}_event"
      end

      # Determines whether the given command is handled.
      # 
      # @param [String] command The command to check for the existence of
      # @return [Boolean] +true+ if the command exists, otherwise +false+
      def command?(command)
        commands.include?(command)
      end
    end

    @commands = {}

    # An authenticated session is missing
    handle :session_missing, :no_session

    # The client is being asked to disconnect
    handle :session_end_requested, :killdashnine do
      room_id = data['roomid']
      if !room_id || room && room.id == room_id
        client.close(true)
        data['msg'] || 'Unknown reason'
      end
    end

    # The client's connection has closed
    handle :session_ended

    # The client re-connected after previously being disconnected
    handle :reconnected

    # A heartbeat was received from Turntable to ensure the client's connection
    # is still valid
    handle :heartbeat

    # A response was receivied from a prior command sent to Turntable
    handle :response_received do
      data
    end

    # Information about the room was updated
    handle :room_updated, :update_room do
      room.attributes = data
      room
    end

    # One or more users have entered the room
    handle :user_entered, :registered do
      data['user'].map do |attrs|
        user = room.build_user(attrs)
        room.listeners << user
        [user]
      end
    end

    # One or more users have left the room
    handle :user_left, :deregistered do
      data['user'].map do |attrs|
        user = room.build_user(attrs)
        room.listeners.delete(user)
        [user]
      end
    end

    # A user has been booted from the room
    handle :user_booted, :booted_user do
      boot = Boot.new(client, data)
      client.room = nil if boot.user == client.user
      boot
    end

    # A user's name / profile has been updated
    handle :user_updated, :update_user do
      fans_change = data.delete('fans') || 0
      user = room.build_user(data)
      user.attributes = {'fans' => user.fans_count + fans_change}

      # Trigger detailed events for exactly what changed to make it easier to
      # detect the various situations
      client.trigger(:user_name_updated, user) if data['name']
      client.trigger(:user_avatar_updated, user) if data['avatarid']
      client.trigger(:fan_added, user, room.build_user(:_id => data['fanid'])) if fans_change > 0
      client.trigger(:fan_removed, user, fans_change.abs) if fans_change < 0

      user
    end

    # User's name has been updated
    handle :user_name_updated

    # A user's avatar has been updated
    handle :user_avatar_updated

    # A user's stickers have been updated
    handle :user_updated, :update_sticker_placements do
      room.build_user(data)
    end

    handle :user_stickers_updated

    # A user spoke in the chat room
    handle :user_spoke, :speak do
      data['senderid'] = data.delete('userid')
      Message.new(client, data)
    end

    # A new fan was added by a user in the room
    handle :fan_added

    # A fan has been removed by a user in the room
    handle :fan_removed

    # A new dj was added to the stage
    handle :dj_added, :add_dj do
      user = room.build_user(data['user'][0].merge('placements' => data['placements']))
      room.djs << user
      user
    end

    # A dj was removed from the stage
    handle :dj_removed, :rem_dj do
      user = room.build_user(data['user'][0])
      room.djs.delete(user)

      if moderator_id = data['modid']
        if moderator_id == 1
          client.trigger(:dj_booed_off, user)
        else
          moderator = room.build_user(:_id => data['user'][0])
          client.trigger(:dj_escorted_off, user, moderator)
        end
      end

      [user]
    end

    # A dj was escorted off the stage by a moderator
    handle :dj_escorted_off

    # A dj was booed off the stage
    handle :dj_booed_off

    # A new moderator was added to the room
    handle :moderator_added, :new_moderator do
      user = room.build_user(data)
      room.moderators << user
      user
    end

    # A moderator was removed from the room
    handle :moderator_removed, :rem_moderator do
      user = room.build_user(data)
      room.moderators.delete(user)
      user
    end

    # There are no more songs to play in the room
    handle :song_unavailable, :nosong do
      client.trigger(:song_ended) if room.current_song
      room.attributes = data['room'].merge('current_song' => nil)
      nil
    end

    # A new song has started playing
    handle :song_started, :newsong do
      client.trigger(:song_ended) if room.current_song
      room.attributes = data['room']
      room.current_song
    end

    # The current song has ended
    handle :song_ended do
      room.current_song
    end

    # A vote was cast for the song
    handle :song_voted, :update_votes do
      song = room.current_song
      initial_up_votes_count = song.up_votes_count
      room.attributes = data['room']

      # Update DJ point count
      dj = room.current_dj
      dj.attributes = {'points' => dj.points + song.up_votes_count - initial_up_votes_count}

      song
    end

    # A user in the room has queued the current song onto their playlist
    handle :song_snagged, :snagged do
      Snag.new(client, data.merge(:song => room.current_song))
    end

    # A song was skipped due to a copyright claim
    handle :song_blocked do
      client.trigger(:song_ended) if room.current_song
      Song.new(client, data)
    end

    # A song was skipped due to a limit on # of plays per hour
    handle :song_limited, :dmca_error do
      client.trigger(:song_ended) if room.current_song
      Song.new(client, data)
    end

    # A private message was received from another user in the room
    handle :message_received, :pmmed do
      Message.new(client, data)
    end

    # A song search has completed and the results are available
    handle :search_completed, :search_complete do
      [[data['docs'].map {|attrs| Song.new(client, attrs)}]]
    end

    # A song search failed to complete
    handle :search_failed

    # The name of the event that was triggered
    # @return [String]
    attr_reader :name

    # The raw arguments list from the event
    # @return [Array<Object>]
    attr_reader :args

    # The raw hash of data parsed from the event
    # @return [Hash<String, Object>]
    attr_reader :data

    # The typecasted results args parsed from the event
    # @return [Array<Array<Object>>]
    attr_reader :results

    # Creates a new event triggered with the given data
    # 
    # @param [Turntabler::Client] client The client that this event is bound to
    # @param [Symbol] command The name of the command that fired the event
    # @param [Array] args The raw argument data from the event
    def initialize(client, command, args)
      @client = client
      @args = args
      @data = args[0]
      @name = self.class.commands[command]
      @results = __send__("typecast_#{command}_event")
      @results = [[@results].compact] unless @results.is_a?(Array)
    end

    private
    # The client that all APIs filter through
    attr_reader :client

    # Gets the current room the user is in
    def room
      client.room
    end
  end
end
