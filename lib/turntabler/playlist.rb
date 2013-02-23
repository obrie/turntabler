require 'turntabler/resource'
require 'turntabler/song'

module Turntabler
  # Represents a collection of songs managed by the user and that can be played
  # within a room 
  class Playlist < Resource
    # Allow the id to be set via the "name" attribute
    # @return [String]
    attribute :id, :name, :load => false

    # Whether this is the currently active playlist
    # @return [Boolean]
    attribute :active, :load => false

    # The songs that have been added to this playlist
    # @return [Array<Turntabler::Song>]
    attribute :songs, :list do |songs|
      songs.map {|attrs| Song.new(client, attrs.merge(:playlist => id))}
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

    # Updates this playlist's information.
    # 
    # @param [Hash] attributes The attributes to update
    # @option attributes [String] :id
    # @return [true]
    # @raise [ArgumentError] if an invalid attribute or value is specified
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   playlist.update(:id => "rock")  # => true
    def update(attributes = {})
      assert_valid_keys(attributes, :id)

      # Update id
      id = attributes.delete(:id)
      update_id(id) if id

      true
    end

    # Whether this is the currently active playlist
    # 
    # @return [Boolean]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   playlist.active   # => true
    def active
      @active = client.user.playlists.all.any? {|playlist| playlist == self && playlist.active?} if @active.nil?
      @active
    end

    # Changes this playlist to be used for queueing new songs with the room.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   playlist.switch   # => true
    def activate
      api('playlist.switch')
      self.attributes = {'active' => true}
      true
    end

    # Permanently deletes this playlist and the list of songs within it.  If this
    # is the currently active playlist, the "default" playlist will become active.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   playlist.delete   # => true
    def delete
      api('playlist.delete')
      true
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
    # Updates the name used to identify this playlist
    def update_id(id)
      client.api('playlist.rename', :old_playlist_name => self.id, :new_playlist_name => id)
      self.attributes = {'name' => id}
      true
    end

    def api(command, options = {})
      options[:playlist_name] = id
      super
    end
  end
end
