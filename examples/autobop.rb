#!/usr/bin/env ruby
# Each time a a new song starts, vote it up
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :song_started do |song|
    song.vote
  end
end
