#!/usr/bin/env ruby
# Response to users who say "/hello" in the chat
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :user_spoke do |message|
    # Respond to "/hello" command
    if (message.content =~ /^\/hello$/)
      room.say("Hey! How are you @#{message.sender.name}?")
    end
  end
end
