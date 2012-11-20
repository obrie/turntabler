#!/usr/bin/env ruby
# Boot users who are on a blacklist
require 'turntabler'

AUTH = ENV['AUTH']  # 'auth+live+xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
USER = ENV['USER']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'
ROOM = ENV['ROOM']  # 'xxxxxxxxxxxxxxxxxxxxxxxx'

Turntabler.run do
  # List of blacklisted user ids
  blacklist = ['xxxxxxxxxxxxxxxxxxxxxxxx', 'xxxxxxxxxxxxxxxxxxxxxxxx']

  client = Turntabler::Client.new(USER, AUTH, :room => ROOM)
  client.on :user_entered do |user|
    user.boot('You are on the blacklist.') if blacklist.include?(user.id)
  end
end
