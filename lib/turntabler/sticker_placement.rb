require 'turntabler/resource'
require 'turntabler/sticker'

module Turntabler
  # Represents a sticker that's been placed on a user's laptop
  class StickerPlacement < Resource
    # The sticker that's been placed
    # @return [Turntabler::Sticker]
    attribute :sticker, :sticker_id do |value|
      Sticker.new(client, :_id => value)
    end

    # The y-coordinate for the sticker
    # @return [Fixnum]
    attribute :top

    # The x-coordinate for the sticker
    # @return [Fixnum]
    attribute :left

    # The degree at which the sticker is tilted
    # @return [Fixnum]
    attribute :angle
  end
end
