#!/usr/bin/env ruby
# Moderator commands
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

# List of moderator ids
moderator_ids = ['xxxxxxxxxxxxxxxxxxxxxxxx', 'xxxxxxxxxxxxxxxxxxxxxxxx']

TT.run(USER, AUTH, :room => ROOM) do
  on :user_spoke do |message|
    # Response to "/mod" command
    if moderator_ids.include?(message.sender.id) && message.text =~ /^\/mod$/
      user.say("Yo #{message.sender.name}, it looks like you are a bot moderator!")
    end
  end
end
