#!/usr/bin/env ruby
# Fan users who enter the room
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :user_entered do |user|
    user.become_fan
  end
end
