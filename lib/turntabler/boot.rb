require 'turntabler/resource'

module Turntabler
  # Represents an event where a user has been booted from a room
  class Boot < Resource
    # The user that was booted from the room
    # @return [Turntabler::User]
    attribute :user, :userid do |value|
      room.build_user(:_id => value)
    end

    # The moderator that booted the user
    # @return [Turntabler::User]
    attribute :moderator, :modid do |value|
      room.build_user(:_id => value)
    end

    # The reason for being booted
    # @return [String]
    attribute :reason
  end
end
