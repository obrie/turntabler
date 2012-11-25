require 'turntabler/resource'

module Turntabler
  # Represents the site preferences for the authorized user
  class Preferences < Resource
    # Send e-mails if a fan starts DJing
    # @return [Boolean]
    attribute :notify_dj

    # Send e-mails when someone becomes a fan
    # @return [Boolean]
    attribute :notify_fan

    # Sends infrequent e-mails about news
    # @return [Boolean]
    attribute :notify_news

    # Sends e-mails at random times with a different subsection of the digits of pi
    # @return [Boolean]
    attribute :notify_random

    # Publishes to facebook songs voted up in public rooms
    # @return [Boolean]
    attribute :facebook_awesome

    # Publishes to facebook when a public room is joined
    # @return [Boolean]
    attribute :facebook_join

    # Publishes to facebook when DJing in a public room
    # @return [Boolean]
    attribute :facebook_dj

    # Loads the user's current Turntable preferences.
    # 
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   preferences.load        # => true
    #   preferences.notify_dj   # => false
    def load
      data = api('user.get_prefs')
      self.attributes = data['result'].inject({}) do |result, (preference, value, id, description)|
        result[preference] = value
        result
      end
      super
    end

    # Updates the user's preferences.
    # 
    # @param [Hash] attributes The attributes to update
    # @option attributes [Boolean] :notify_dj
    # @option attributes [Boolean] :notify_fan
    # @option attributes [Boolean] :notify_news
    # @option attributes [Boolean] :notify_random
    # @option attributes [Boolean] :facbeook_awesome
    # @option attributes [Boolean] :facebook_join
    # @option attributes [Boolean] :facebook_dj
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   preferences.update(:notify_dj => false)   # => true
    def update(attributes = {})
      assert_valid_values(attributes, :notify_dj, :notify_fan, :notify_news, :notify_random, :facebook_awesome, :facebook_join, :facebook_dj)
      api('user.edit_prefs', attributes)
      self.attributes = attributes
      true
    end
  end
end
