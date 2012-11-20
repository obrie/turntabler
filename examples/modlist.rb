#!/usr/bin/env ruby
# Moderator commands
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

Turntabler.run do
  # List of moderator ids
  moderator_ids = ['xxxxxxxxxxxxxxxxxxxxxxxx', 'xxxxxxxxxxxxxxxxxxxxxxxx']

  client = Turntabler::Client.new(USER, AUTH, :room => ROOM)
  client.on :user_spoke do |message|
    # Response to "/mod" command
    if moderator_ids.include?(message.sender.id) && message.text =~ /^\/mod$/
      client.user.say("Yo #{message.sender.name}, it looks like you are a bot moderator!")
    end
  end
end
