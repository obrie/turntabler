#!/usr/bin/env ruby
# Vote up a song when 2 people say "bop" in the chat
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

Turntabler.run do
  client = Turntabler::Client.new(USER, AUTH, :room => ROOM)

  bops_count = 0

  client.on :user_spoke do |message|
    bops_count += 1 if message.text =~ /bop/
    client.room.current_song.vote if bops_count == 2
  end

  client.on :song_started do |song|
    bops_count = 0
  end
end
