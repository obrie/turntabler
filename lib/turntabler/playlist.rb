require 'turntabler/resource'
require 'turntabler/song'

module Turntabler
  # Represents a collection of songs managed by the user and that can be played
  # within a room 
  class Playlist < Resource
    # The songs that have been added to this playlist
    # @return [Array<Turntabler::Song>]
    attribute :songs, :list do |songs|
      songs.map {|attrs| Song.new(client, attrs)}
    end

    # Loads the attributes for this playlist.  Attributes will automatically load
    # when accessed, but this allows data to be forcefully loaded upfront.
    # 
    # @param [Hash] options The configuration options
    # @option options [Boolean] minimal (false) Whether to only include the identifiers for songs and not the entire metadata
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   playlist.load   # => true
    #   playlist.songs  # => [#<Turntabler::Song ...>, ...]
    def load(options = {})
      assert_valid_keys(options, :minimal)
      options = {:minimal => false}.merge(options)

      data = api('playlist.all', options)
      self.attributes = data
      super()
    end
    
    # Gets the song with the given id.
    # 
    # @param [String] song_id The id for the song
    # @return [Turntabler::Song]
    # @raise [Turntabler::Error] if the list of songs fail to load
    # @example
    #   playlist.song('4fd8...')    # => #<Turntabler::Song ...>
    def song(song_id)
      songs.detect {|song| song.id == song_id}
    end

    private
    def api(command, options = {})
      options[:playlist_name] = id
      super
    end
  end
end
