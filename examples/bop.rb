#!/usr/bin/env ruby
# Vote up a song when someone says "bop" in the chat
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :user_spoke do |message|
    if message.content =~ /bop/
      room.current_song.vote
    end
  end
end
