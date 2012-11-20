#!/usr/bin/env ruby
# Fan users who enter the room
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

Turntabler.run do
  client = Turntabler::Client.new(USER, AUTH, :room => ROOM)
  client.on :user_entered do |user|
    user.become_fan
  end
end
