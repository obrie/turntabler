#!/usr/bin/env ruby
# list the first 200 rooms
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx''

Turntabler.run do
  client = Turntabler::Client.new(EMAIL, PASSWORD)
  client.rooms.list(:limit => 100).each_with_index do |room,i|
    puts "##{i}. #{room.id} #{room.name}"
  end
end