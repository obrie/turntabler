#!/usr/bin/env ruby
# Boot users who are on a blacklist
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

# List of blacklisted user ids
blacklist = ['xxxxxxxxxxxxxxxxxxxxxxxx', 'xxxxxxxxxxxxxxxxxxxxxxxx']

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  on :user_entered do |user|
    user.boot('You are on the blacklist.') if blacklist.include?(user.id)
  end
end
