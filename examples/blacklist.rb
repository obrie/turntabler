#!/usr/bin/env ruby
# Boot users who are on a blacklist
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

# List of blacklisted user ids
blacklist = ['xxxxxxxxxxxxxxxxxxxxxxxx', 'xxxxxxxxxxxxxxxxxxxxxxxx']

TT.run(USER, AUTH, :room => ROOM) do
  on :user_entered do |user|
    user.boot('You are on the blacklist.') if blacklist.include?(user.id)
  end
end
