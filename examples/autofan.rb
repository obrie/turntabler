#!/usr/bin/env ruby
# Fan users who enter the room
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

TT.run(USER, AUTH, :room => ROOM) do
  on :user_entered do |user|
    user.become_fan
  end
end
