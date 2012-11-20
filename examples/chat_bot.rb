#!/usr/bin/env ruby
# Response to users who say "/hello" in the chat
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

TT.run(USER, AUTH, :room => ROOM) do
  on :user_spoke do |message|
    # Respond to "/hello" command
    if (message.text =~ /^\/hello$/)
      client.user.say("Hey! How are you @#{message.sender.name}?")
    end
  end
end
