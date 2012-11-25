require 'turntabler/playlist'
require 'turntabler/preferences'
require 'turntabler/user'
require 'turntabler/sticker_placement'

module Turntabler
  # Represents a user who has authorized with the Turntable service
  class AuthorizedUser < User
    # The current availability status of the user ("available", "unavailable", or "away")
    # @return [String]
    attribute :status

    # The authentication token required to connect to the API
    # @return [String]
    attribute :auth

    # The user's unique identifier on Facebook
    # @return [String]
    attribute :facebook_id, :fbid

    # The user's unique identifier on Twitter
    # @return [String]
    attribute :twitter_id, :twitterid

    # The e-mail address the user registered with on Turntable.  This is
    # typically only set if the user didn't log in via Facebook or Twitter.
    # @return [String]
    attribute :email

    # Whether the user has a password associated with their account.  This is
    # typically only the case if the user didn't log in via Facebook or Twitter.
    # @return [Boolean]
    attribute :has_password, :has_tt_password

    # The user's current Turntable preferences
    # @return [Turntabler::Preferences]
    attr_reader :preferences

    # @api private
    def initialize(client, *)
      @status = 'available'
      @playlists = {}
      @preferences = Preferences.new(client)
      super
    end

    # Authenticates the current user with turntable.
    # 
    # @api private
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    def authenticate
      api('user.authenticate')
      true
    end

    # Loads the attributes for this user.  Attributes will automatically load
    # when accessed, but this allows data to be forcefully loaded upfront.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.load     # => true
    #   user.email    # => "john.doe@gmail.com"
    def load
      data = api('user.info')
      self.attributes = data
      super
    end

    # Updates this user's profile information.
    # 
    # @param [Hash] attributes The attributes to update
    # @option attributes [String] :name
    # @option attributes [String] :status Valid values include "available", "unavailable", and "away"
    # @option attributes [String] :laptop_name Valid values include "mac", "pc", "linux", "chrome", "iphone", "cake", "intel", and "android"
    # @option attributes [String] :twitter_id
    # @option attributes [String] :facebook_url
    # @option attributes [String] :website
    # @option attributes [String] :about
    # @option attributes [String] :top_artists
    # @option attributes [String] :hangout
    # @return [true]
    # @raise [ArgumentError] if an invalid attribute or value is specified
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.update(:status => "away")        # => true
    #   user.update(:laptop_name => "mac")    # => true
    #   user.update(:name => "...")           # => true
    def update(attributes = {})
      assert_valid_keys(attributes, :name, :status, :laptop_name, :twitter_id, :facebook_url, :website, :about, :top_artists, :hangout)

      # Update status
      status = attributes.delete(:status)
      update_status(status) if status

      # Update laptop
      laptop_name = attributes.delete(:laptop_name)
      update_laptop(laptop_name) if laptop_name

      # Update profile with remaining data
      update_profile(attributes) if attributes.any?

      true
    end

    # Loads the list of users that are connected to the current user through a
    # social network like Facebook or Twitter.
    # 
    # @return [Array<Turntabler::User>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.buddies    # => [#<Turntabler::User ...>, ...]
    def buddies
      data = api('user.get_buddies')
      data['buddies'].map {|id| User.new(client, :_id => id)}
    end

    # Loads the list of users that the current user is a fan of.
    # 
    # @return [Array<Turntabler::User>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.fan_of   # => [#<Turntabler::User ...>, ...]
    def fan_of
      data = api('user.get_fan_of')
      data['fanof'].map {|id| User.new(client, :_id => id)}
    end

    # Loads the list of users that are a fan of the current user.
    # 
    # @return [Array<Turntabler::User>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.fans   # => [#<Turntabler::User ...>, ...]
    def fans
      data = api('user.get_fans')
      data['fans'].map {|id| User.new(client, :_id => id)}
    end

    # Gets the avatars that can be set by this user.
    # 
    # @note This may load the user's data in order to get the ACL if it's not available already
    # @return [Array<Turntabler::Avatar>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.avatars    # => [#<Turntabler::Avatar ...>, ...]
    def avatars
      client.avatars.select {|avatar| avatar.available?}
    end

    # Gets the playlist with the given id.
    # 
    # @param [String] id The unique identifier for the playlist
    # @return [Turntabler::Playlist]
    # @example
    #   user.playlist             # => #<Turntabler::Playlist id="default" ...>
    #   user.playlist("rock")     # => #<Turntabler::Playlist id="rock" ...>
    def playlist(id = 'default')
      @playlists[id] ||= Playlist.new(client, :_id => id)
    end

    # Gets the stickers that have been purchased by this user.
    # 
    # @return [Array<Turntabler::Sticker>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.stickers_purchased   # => [#<Turntabler::Sticker ...>, ...]
    def stickers_purchased
      data = api('sticker.get_purchased_stickers')
      data['stickers'].map {|sticker_id| Sticker.new(client, :_id => sticker_id)}
    end

    # Gets the users that have been blocked by this user.
    # 
    # @return [Array<Turntabler::User>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.blocks   # => [#<Turntabler::User ...>, ...]
    def blocks
      data = api('block.list_all')
      data['blocks'].map {|attrs| User.new(client, attrs['block']['blocked'])}
    end
    
    private
    # Updates the user's profile information
    def update_profile(attributes = {})
      assert_valid_keys(attributes, :name, :twitter_id, :facebook_url, :website, :about, :top_artists, :hangout)

      # Convert attribute names over to their Turntable equivalent
      {:twitter_id => :twitter, :facebook_url => :facebook, :top_artists => :topartists}.each do |from, to|
        attributes[to] = attributes.delete(from) if attributes[from]
      end

      api('user.modify_profile', attributes)
      self.attributes = attributes
      true
    end

    # Updates the laptop currently being used
    def update_laptop(name)
      assert_valid_values(name, *%w(mac pc linux chrome iphone cake intel android))

      api('user.modify', :laptop => name)
      self.attriutes = {'laptop' => name}
      true
    end

    # Sets the user's current status
    def update_status(status = self.status)
      assert_valid_values(status, *%w(available unavailable away))

      api('presence.update', :status => status)
      self.attributes = {'status' => status}
      true
    end
  end
end
