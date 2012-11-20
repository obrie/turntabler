#!/usr/bin/env ruby
# Each time a a new song starts, vote it up
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

TT.run(USER, AUTH, :room => ROOM) do
  on :song_started do |song|
    song.vote
  end
end
