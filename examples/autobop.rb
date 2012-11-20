#!/usr/bin/env ruby
# Each time a a new song starts, vote it up
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

Turntabler.run do
  client = Turntabler::Client.new(USER, AUTH, :room => ROOM)
  client.on :song_started do |song|
    song.vote
  end
end
