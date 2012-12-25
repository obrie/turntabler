#!/usr/bin/env ruby
# Vote up a song when 2 people say "bop" in the chat
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

bops_count = 0

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :user_spoke do |message|
    bops_count += 1 if message.content =~ /bop/
    room.current_song.vote if bops_count == 2
  end

  on :song_started do |song|
    bops_count = 0
  end
end
