#!/usr/bin/env ruby
# Keep the last activity timestamp of everyone in the room
require 'turntabler'

EMAIL = ENV['EMAIL']        # 'xxxxx@xxxxx.com'
PASSWORD = ENV['PASSWORD']  # 'xxxxx'
ROOM = ENV['ROOM']          # 'xxxxxxxxxxxxxxxxxxxxxxxx'

# Reset the users list
last_activity = {}

TT.run(EMAIL, PASSWORD, :room => ROOM) do
  room.listeners.each do |user|
    last_activity[user.id] = Time.now
  end

  on :user_entered do |user|
    last_activity[user.id] = Time.now
  end

  on :user_left do |user|
    last_activity.delete(user.id)
  end

  on :user_spoke do |message|
    last_activity[message.sender.id] = Time.now
  end

  on :dj_added do |user|
    last_activity[user.id] = Time.now
  end

  on :dj_removed do |user|
    last_activity[user.id] = Time.now
  end

  on :song_voted do |song|
    song.votes.each do |vote|
      last_activity[vote.user.id] = Time.now
    end
  end

  on :song_snagged do |snag|
    last_activity[snag.user.id] = Time.now
  end
end
