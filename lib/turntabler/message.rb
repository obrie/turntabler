require 'turntabler/resource'
require 'turntabler/user'

module Turntabler
  # Represents a message that was sent to or from the current user.  This can
  # either be within the context of a room or a private conversation.
  class Message < Resource
    # The user who sent the message
    # @return [Turntabler::User]
    attribute :sender, :senderid do |id|
      room? ? room.build_user(:_id => id) : User.new(client, :_id => id)
    end

    # The text of the message
    # @return [String]
    attribute :content, :text

    # The time at which the message was created
    # @return [Time]
    attribute :created_at, :time do |value|
      Time.at(value)
    end
  end
end
