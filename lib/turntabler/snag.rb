require 'turntabler/resource'

module Turntabler
  # Represents a song that was snagged
  class Snag < Resource
    # The user who snagged the song
    # @return [Turntabler::User]
    attribute :user, :userid do |value|
      room.build_user(:_id => value)
    end

    # The song that was snagged
    # @return [Turntabler::Song]
    attribute :song
  end
end
