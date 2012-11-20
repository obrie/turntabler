#!/usr/bin/env ruby
# Vote up a song when someone says "bop" in the chat
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

Turntabler.run do
  client = Turntabler::Client.new(USER, AUTH, :room => ROOM)
  client.on :user_spoke do |message|
    if message.text =~ /bop/
      client.room.current_song.vote
    end
  end
end
