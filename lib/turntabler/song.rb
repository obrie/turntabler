require 'turntabler/resource'
require 'turntabler/user'
require 'turntabler/vote'

module Turntabler
  # Represents a song that can be played on Turntable
  class Song < Resource
    # The title of the song
    # @return [String]
    attribute :title, :song

    # The standard code id for this song
    # @return [String]
    attribute :isrc

    # The name of the artist
    # @return [String]
    attribute :artist

    # The name of the album this song is on
    # @return [String]
    attribute :album

    # The type of music
    # @return [String]
    attribute :genre

    # The label that produced the music
    # @return [String]
    attribute :label

    # The URL for the cover art image
    # @return [String]
    attribute :cover_art_url, :coverart

    # Number of seconds the song lasts
    # @return [Fixnum]
    attribute :length

    # Whether this song can be snagged
    # @return [Boolean]
    attribute :snaggable
    
    # The source from which the song was uploaded
    # @return [String]
    attribute :source
    
    # The id of the song on the original source service
    # @return [String]
    attribute :source_id, :sourceid
    
    # The playlist this song is referenced from
    # @return [Turntabler::Playlist]
    attribute :playlist do |id|
      client.user.playlists.build(:_id => id)
    end
    
    # The time at which the song was started
    # @return [Time]
    attribute :started_at, :starttime

    # The number of up votes this song has received.
    # @note This is only available for the current song playing in a room
    # @return [Fixnum]
    attribute :up_votes_count, :upvotes, :load => false
    
    # The number of down votes this song has received.
    # @note This is only available for the current song playing in a room
    # @return [Fixnum]
    attribute :down_votes_count, :downvotes, :load => false
    
    # The log of votes this song has received.  This will only include up votes
    # or down votes that were previously up votes.
    # @note This is only available for the current song playing in a room
    # @return [Array<Vote>]
    attribute :votes, :votelog, :load => false do |votes|
      votes.each do |(user_id, direction)|
        self.votes.delete_if {|vote| vote.user.id == user_id}
        self.votes << Vote.new(client, :userid => user_id, :direction => direction) if user_id && !user_id.empty?
      end
      self.votes
    end
    
    # The percentage score for this song based on the number of votes
    # @note This is only available for the current song playing in a room
    # @return [Float]
    attribute :score, :load => false
    
    # The DJ that played this song
    # @note This is only available for the current song playing in a room
    # @return [Turntabler::User]
    attribute :played_by, :djid, :load => false do |value|
      room? ? room.build_user(:_id => value) : User.new(client, :_id => value)
    end

    # @api private
    def initialize(client, *)
      @up_votes_count = 0
      @down_votes_count = 0
      @votes = []
      @score = 0
      @playlist = client.user.playlists.build(:_id => 'default')
      super
    end

    # The time at which this song will end playing.
    # 
    # @return [Time]
    # @example
    #   song.ends_at  # => 2013-01-05 12:14:25 -0500
    def ends_at
      started_at + client.clock_delta + length if started_at
    end

    # The number of seconds remaining to play in the song
    # 
    # @return [Fixnum]
    # @example
    #   song.seconds_remaining  # => 12
    def seconds_remaining
      ends_at ? (ends_at - started_at).round : 0
    end

    # Loads the attributes for this song.  Attributes will automatically load
    # when accessed, but this allows data to be forcefully loaded upfront.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   song.load     # => true
    #   song.title    # => "..."
    def load
      data = api('playlist.get_metadata', :playlist_name => playlist.id, :files => [id])
      self.attributes = data['files'][id]
      super
    end

    # Skips the song.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @raise [Turntabler::Error] if the song is not playing in the current song
    # @example
    #   song.skip   # => true
    def skip
      assert_current_song
      api('room.stop_song', :roomid => room.id, :section => room.section)
      true
    end

    # Vote for the song.
    # 
    # @param [Symbol] direction The direction to vote the song (:up or :down)
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @raise [Turntabler::Error] if the song is not playing in the current song
    # @example
    #   song.vote         # => true
    #   song.vote(:down)  # => true
    def vote(direction = :up)
      assert_current_song
      api('room.vote',
        :roomid => room.id,
        :section => room.section,
        :val => direction,
        :songid => id,
        :vh => digest("#{room.id}#{direction}#{id}"),
        :th => digest(rand),
        :ph => digest(rand)
      )
      true
    end

    # Triggers the heart animation for the song.
    # 
    # @note This will not add the song to the user's playlist
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @raise [Turntabler::Error] if the song is not playing in the current song
    # @example
    #   song.snag   # => true
    def snag
      assert_current_song
      sh = digest(rand)
      api('snag.add',
        :djid => room.current_dj.id,
        :songid => id,
        :roomid => room.id,
        :section => room.section,
        :site => 'queue',
        :location => 'board',
        :in_queue => 'false',
        :blocked => 'false',
        :vh => digest([client.user.id, room.current_dj.id, id, room.id, 'queue', 'board', 'false', 'false', sh] * '/'),
        :sh => sh,
        :fh => digest(rand)
      )
      true
    end
    
    # Adds the song to one of the user's playlists.
    # 
    # @param [Hash] options The options for where to add the song
    # @option options [String] :playlist ("default") The playlist to enqueue the song in
    # @option options [Fixnum] :index (0) The location in the playlist to insert the song
    # @return [true]
    # @raise [ArgumentError] if an invalid option is specified
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   song.enqueue(:index => 1)   # => true
    def enqueue(options = {})
      assert_valid_keys(options, :playlist, :index)
      options = {:playlist => playlist.id, :index => 0}.merge(options)

      # Create a copy of the song so that the playlist can get set properly
      song = dup
      song.attributes = {:playlist => options[:playlist]}
      playlist, index = song.playlist, options[:index]

      api('playlist.add', :playlist_name => playlist.id, :song_dict => {:fileid => id}, :index => index)
      playlist.songs.insert(index, song) if playlist.loaded?
      true
    end
    
    # Removes the song from the playlist at the given index.
    # 
    # @return [true]
    # @raise [ArgumentError] if an invalid option is specified
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   song.dequeue    # => true
    def dequeue
      api('playlist.remove', :playlist_name => playlist.id, :index => index)
      playlist.songs.delete(self)
      true
    end

    # Move a song from one location in the playlist to another.
    # 
    # @param [Fixnum] to_index The index to move the song to
    # @return [true]
    # @raise [ArgumentError] if an invalid option is specified
    # @raise [Turntabler::Error] if the command fails
    #   song.move(5)    # => true
    def move(to_index)
      api('playlist.reorder', :playlist_name => playlist.id, :index_from => index, :index_to => to_index)
      playlist.songs.insert(to_index, playlist.songs.delete(self))
      true
    end
    
    private
    # Asserts that this is the song currently being played in the room the user
    # is in.  Raises Turntabler::Error if this is not the case.
    def assert_current_song
      raise(APIError, "Song \"#{id}\" is not currently playing") unless room.current_song == self
    end
    
    # Gets the index of this song within the given playlist.  Raises Turntabler::Error
    # if the song cannot be found in the playlist.
    def index
      index = playlist.songs.index(self)
      raise(APIError, "Song \"#{id}\" is not in playlist \"#{playlist.id}\"") unless index
      index
    end
  end
end
