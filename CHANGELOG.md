# master

* Fix song searches not respecting request timeouts
* Add Song#released_on

## 0.3.4 / 2013-07-11

* Fix heartbeat responses not being sent properly resulting in periodic disconnects
* Fix Resource initialization not working on Ruby 2.0

## 0.3.3 / 2013-03-18

* Fix Preferences#update not validating options properly
* Update User#load to use the new user.get_profile API parameters
* Update Song#skip to use the new room.stop_song API parameters

## 0.3.2 / 2013-02-24

* Fix songs being added to the wrong playlist when played by other djs
* Don't load song data when accessing the playlist or started_at timestamp

## 0.3.1 / 2013-02-24

* Rename Song#dequeue to #rotate_out to avoid confusion with its previous behavior

## 0.3.0 / 2013-02-23

* Fix playlist order not being maintained properly in process
* Rename Song#enqueue to Song#add and Song#dequeue to Song#remove
* Song#dequeue and #move no longer allow the playlist to be specified since it's known upfront
* Fix Song#load not getting metadata from the correct playlist
* Add Song#playlist
* Add room_description_updated event
* Add song_skipped / song_moderated events
* Add #started_at, #ends_at, and #seconds_remaining to Song
* Add dj_escorted_off / dj_booed_off events
* Add fan_added / fan_removed events
* Add user_name_updated / user_avatar_updated / user_stickers_updated events

## 0.2.1 / 2013-02-16

* Fix exceptions on initial connection not causing reconnection process to kick in
* Fix exceptions in reconnects causing the reconnect process to halt retrying
* Fix reconnects not occurring when socket is closed without a killdashnine event from Turntable
* Fix exceptions in keepalive timer causing the EM reactor to be shut down

## 0.2.0 / 2013-02-16

* Respect the keepalive update interval from API responses
* Add official support for trigger custom events
* Rename RoomDirectory#list to RoomDirectory#all
* Add full support for playlists API
* Fix Modlist example not sending messages to the room

## 0.1.4 / 2012-01-08

* Fix Bop / ChatBot / Switch examples not working
* Fix Message#sender not set properly on user_spoke events
* Fix Client#room not being reset when leaving a room
* Fix roomid / section not being specify consistently in room APIs

## 0.1.3 / 2012-12-25

* Fix references from Message#text to Message#content in examples

## 0.1.2 / 2012-12-01

* Fix song searches being allowed when the user isn't in a room
* Allow title / artist / duration to be explicitly specified in song searches

## 0.1.1 / 2012-11-27

* Fix gemspec filename

## 0.1.0 / 2012-11-27

* Add :reconnected event for hooking in logic when a client reconnects
* Gracefully handle error cases where APIs are called from a root fiber
* Don't re-define the TT constant if it's already been defined
* Add Turntabler::Client#user_by_name for looking up users by their name instead of id
* Allow authentication via user ids / auth tokens if a password is unavailable
* Authenticate using emails / passwords instead of user ids / auth tokens
* Fix exceptions in callbacks not causing one-time callbacks to be unregistered
* Only catch StandardError, not Exception, in Turntabler#run
* Fix song votes being tracked with empty user ids
* Fix the current dj's points not getting updated on song_voted events
* Fix song_ended event never getting fired
* Fix laptop names not being able to be updated

## 0.0.1 / 2012-11-20

* Initial revision
