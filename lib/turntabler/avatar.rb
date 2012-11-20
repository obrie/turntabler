require 'turntabler/resource'

module Turntabler
  # Represents an avatar for DJ'ing
  class Avatar < Resource
    # The minimum points required to activate this avatar
    # @return [Fixnum]
    attribute :minimum_points, :min

    # The access control required to activate this avatar
    # @return [Fixnum]
    attribute :acl

    # Determines whether this avatar is available to the current user.
    # 
    # @return [Boolean] +true+ if the avatar is available, otherwise +false+
    def available?
      client.user.points >= minimum_points && (!acl || client.user.acl >= acl)
    end

    # Updates the current user's avatar to this one.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   avatar.set    # => true
    def set
      api('user.set_avatar', :avatarid => id)
      client.user.attributes = {'avatarid' => id}
      client.user.avatar.attributes = {'min' => minimum_points, 'acl' => acl}
      true
    end
  end
end
