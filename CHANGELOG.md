# master

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
