#!/usr/bin/env ruby
# Moderator commands
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

# List of moderator ids
moderator_ids = ['xxxxxxxxxxxxxxxxxxxxxxxx', 'xxxxxxxxxxxxxxxxxxxxxxxx']

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :user_spoke do |message|
    # Response to "/mod" command
    if moderator_ids.include?(message.sender.id) && message.content =~ /^\/mod$/
      room.say("Yo #{message.sender.name}, it looks like you are a bot moderator!")
    end
  end
end
