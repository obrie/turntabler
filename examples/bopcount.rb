#!/usr/bin/env ruby
# Vote up a song when 2 people say "bop" in the chat
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

bops_count = 0

Turntabler.run(USER, AUTH, :room => ROOM) do
  on :user_spoke do |message|
    bops_count += 1 if message.text =~ /bop/
    room.current_song.vote if bops_count == 2
  end

  on :song_started do |song|
    bops_count = 0
  end
end
