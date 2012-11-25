require 'turntabler/resource'

module Turntabler
  # Represents a virtual sticker that can be placed on a user
  class Sticker < Resource
    # Allow the id to be set via the "sticker_id" attribute
    # @return [String]
    attribute :id, :sticker_id

    # The human-readable name for the sticker
    # @return [String]
    attribute :name

    # A longer explanation for the sticker
    # @return [String]
    attribute :description

    # The type of sticker (such as "laptop_sticker")
    # @return [String]
    attribute :category

    # The cost to purchase this sticker for use
    # @return [Fixnum]
    attribute :price

    # Whether this sticker can be used ("active")
    # @return [String]
    attribute :state

    # The uri for the sticker
    # @return [String]
    attribute :path

    # Sets the current user's stickers.
    # 
    # @param [Fixnum] top The y-coordinate of the sticker
    # @param [Fixnum] left The x-coordinate of the sticker
    # @param [Float] angle The degree at which the sticker is angled
    # @return [true]
    # @raise [Turntabler::Error] if the command fails
    # @example
    #   sticker.place(126, 78, -23)   # => true
    def place(top, left, angle)
      api('sticker.place', :placement => [:sticker_id => id, :top => top, :left => left, :angle => angle], :is_dj => client.user.dj?, :roomid => room.id, :section => room.section)
      true
    end
  end
end
