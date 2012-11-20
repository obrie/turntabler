require 'turntabler/resource'
require 'turntabler/user'

module Turntabler
  # Represents a vote that was made within a room
  class Vote < Resource
    # The user who cast the vote
    # @return [Turntabler::User]
    attribute :user, :userid do |value|
      room? ? room.build_user(:_id => value) : User.new(client, :_id => value)
    end

    # Whether the user voted +:up+ or +:down+
    # @return [Symbol]
    attribute :direction do |value|
      value.to_sym
    end
  end
end
