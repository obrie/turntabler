require 'turntabler/resource'
require 'turntabler/avatar'
require 'turntabler/message'
require 'turntabler/sticker_placement'

module Turntabler
  # Represents an unauthorized user on Turntable
  class User < Resource
    # Allow the id to be set via the "userid" attribute
    # @return [String]
    attribute :id, :userid, :load => false

    # The DJ name for this user
    # @return [String]
    attribute :name, :name, :username

    # The name of the laptop the DJ uses
    # @return [String]
    attribute :laptop_name, :laptop

    # The version # for the laptop
    # @return [String]
    attribute :laptop_version

    # The total number of points accumulated all-time
    # @return [Fixnum]
    attribute :points

    # The access control determining what is authorized
    # @return [Fixnum]
    attribute :acl

    # The number of fans this user has
    # @return [Fixnum]
    attribute :fans_count, :fans

    # The user's unique identifier on Facebook (only available if the user is
    # connected to the authorized user through Facebook)
    # @return [String]
    attribute :facebook_url, :facebook
    
    # The user's unique identifier on Twitter (only available if the user is
    # connected to the authorized user through Twitter)
    # @return [String]
    attribute :twitter_id, :twitter, :twitterid_lower

    # The user's personal website
    # @return [String]
    attribute :website

    # A brief description about the user
    # @return [String]
    attribute :about

    # The user's favorite artists
    # @return [String]
    attribute :top_artists, :topartists

    # Whether on Turntable the user likes to hang out
    # @return [String]
    attribute :hangout

    # The user's currently active avatar
    # @return [Turntabler::Avatar]
    attribute :avatar, :avatarid do |value|
      Avatar.new(client, :_id => value)
    end

    # The placements of stickers on the user's laptop
    # @return [Array<Turntabler::StickerPlacement>]
    attribute :sticker_placements, :placements do |placements|
      placements.map {|attrs| StickerPlacement.new(client, attrs)}
    end

    # Loads the attributes for this user.  Attributes will automatically load
    # when accessed, but this allows data to be forcefully loaded upfront.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.load         # => true
    #   user.laptop_name  # => "chrome"
    def load
      data = api('user.get_profile', :userid => id)
      self.attributes = data
      super
    end
    
    # Gets the availability status for this user.
    # 
    # @return [String] "available" / "unavailable"
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.presence   # => "available"
    def presence
      data = api('presence.get', :uid => id)
      data['presence']['status']
    end

    # Gets the stickers that are currently placed on the user.
    # 
    # @param [Boolean] reload Whether to forcefully reload the user's list of sticker placements
    # @return [Array<Turntabler::StickerPlacement>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.sticker_placements   # => [#<Turntabler::StickerPlacement ...>, ...]
    def sticker_placements(reload = false)
      self.attributes = api('sticker.get_placements', :userid => id) if reload || !@sticker_placements
      @sticker_placements
    end

    # Marks the current user as a fan of this user.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.become_fan   # => true
    def become_fan
      api('user.become_fan', :djid => id)
      true
    end

    # Marks the current user no longer as a fan of this user.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.unfan    # => true
    def unfan
      api('user.remove_fan', :djid => id)
      true
    end

    # Sends a private message to this user.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.say("Hey what's up?")    # => true
    def say(content)
      api('pm.send', :receiverid => id, :text => content)
      true
    end

    # Gets the private conversation history with this user.
    # 
    # @return [Array<Turntabler::Message>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.messages   # => [#<Turntabler::Message ...>, ...]
    def messages
      data = api('pm.history', :receiverid => id)
      data['history'].map {|attrs| Message.new(client, attrs)}
    end

    # Is the user currently a listener in the room?
    # 
    # @return [Boolean] +true+ if the user is a listener, otherwise +false+
    # @example
    #   user.listener?    # => false
    def listener?
      !room.listener(id).nil?
    end

    # Is the user currently DJing in the room?
    # 
    # @return [Boolean] +true+ if the user is a dj, otherwise +false+
    # @example
    #   user.dj?    # => false
    def dj?
      !room.dj(id).nil?
    end

    # Stops the user from DJing.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.remove_as_dj   # => true
    def remove_as_dj
      api('room.rem_dj', :roomid => room.id, :section => room.section, :djid => id)
      true
    end

    # Is the user currently a moderator for the room?
    # 
    # @return [Boolean] +true+ if the user is a moderator, otherwise +false+
    # @example
    #   user.moderator?   # => false
    def moderator?
      !room.moderator(id).nil?
    end

    # Adds the user as a moderator in the current room.
    # 
    #   user.add_as_moderator   # => true
    def add_as_moderator
      api('room.add_moderator', :roomid => room.id, :section => room.section, :target_userid => id)
      true
    end

    # Removes the user from being a moderator in the current room.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.remove_as_moderator    # => true
    def remove_as_moderator
      api('room.rem_moderator', :roomid => room.id, :section => room.section, :target_userid => id)
      true
    end

    # Gets the location of the user.
    # 
    # @note This will make the current user a fan of this user
    # @param [Boolean] all_info Whether full detailed information should be provided about the room and user
    # @return [Array<Turntabler::Room>]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.stalk    # => #<Turntabler::User ...>
    def stalk(all_info = false)
      become_fan unless client.user.fan_of.include?(self)
      client.rooms.with_friends.detect do |room|
        room.listener(id)
      end
    end

    # Blocks this user from being able to send private messages.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.block    # => true
    def block
      api('block.add', :blockedid => id)
      true
    end

    # Unblocks this user from being able to send private messages.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.unblock    # => true
    def unblock
      api('block.remove', :blockedid => id)
      true
    end

    # Boots the user for the specified reason.
    # 
    # @param [String] reason The reason why the user is being booted
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.boot('Broke rules')    # => true
    def boot(reason = '')
      api('room.boot_user', :roomid => room.id, :section => room.section, :target_userid => id, :reason => reason)
      true
    end

    # Reports abuse by a user.
    # 
    # @param [String] reason The reason the user is being reported
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   user.report('Verbal abuse ...')  # => true
    def report(reason = '')
      api('room.report_user', :roomid => room.id, :section => room.section, :reported => id, :reason => reason)
      true
    end
  end
end
