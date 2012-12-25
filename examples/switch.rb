#!/usr/bin/env ruby
# On/Off bot switch
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

# Bot is on by default
is_on = true

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :user_spoke do |message|
    if is_on
      # The bot is on
      case message.content
      when /^\/status$/
        user.say 'The bot is currently turned on.'
      when /^\/off$/
        user.say 'The bot is now turned off.'
        is_on = false
      when /^\/hello$/
        # Add other logic here for when the bot is turned on. For example:
        # Respond to "/hello" command
        user.say "Hey! How are you #{message.sender.name}?"
      end
    else
      # The bot is off
      case message.content
      when /^\/status$/
        user.say 'The bot is currently turned on.'
      when /^\/on$/
        user.say 'The bot is now turned off.'
        is_on = true
      end

      # Add other logic here for when the bot is turned off
    end
  end
end
