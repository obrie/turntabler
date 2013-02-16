require 'turntabler/playlist'

module Turntabler
  # Provides a set of helper methods for interacting with a user's playlists.
  class PlaylistDirectory
    include Assertions

    # @api private
    def initialize(client)
      @client = client
      @playlists = {}
    end

    # Creates a new playlist with the given id.  This should only be used if
    # the playlist doesn't already exist.
    # 
    # @note This will automatically enter the playlist when it is created
    # @param [String] id The unique identifier of the playlist
    # @return [Turntabler::Playlist]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   playlists.create("Rock")  # => #<Turntabler::Playlist ...>
    def create(id)
      api('playlist.create', :playlist_name => id)
      build(:_id => id)
    end

    # Gets the list of playlists created.
    # 
    # @return [Array<Turntabler::Playlist>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   playlists.all   # => [#<Turntabler::Playlist ...>, ...]
    def all
      data = api('playlist.list_all')
      data['list'].map {|attrs| build(attrs)}
    end

    # Gets the playlist represented by the given attributes.
    # 
    # If the playlist hasn't been previously accessed, then a new Playlist
    # instance will get created.
    # 
    # @api private
    # @param [Hash] attrs The attributes representing the playlist
    # @return [Turntabler::Playlist]
    def build(attrs)
      playlist = Playlist.new(client, attrs)

      # Update existing in cache or cache a new playlist
      if existing = @playlists[playlist.id]
        playlist = existing
        playlist.attributes = attrs
      else
        @playlists[playlist.id] = playlist
      end

      playlist
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
