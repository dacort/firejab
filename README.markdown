Firejab
=====

Firejab is a simple gem for connecting Campfire to Jabber. All communication is through a Jabber (or gchat) user.

Overview
-----

All Firejab needs to function is the site and room id for Campfire, and authentication information for both Campfire and Jabber. It just takes two lines to run the bot:

``` ruby
c = Firejab::Connection.new(
  :domain   => campfire_domain,
  :room_id  => campfire_room_id,
  :token    => campfire_token,
  :jabber => {
    :username => jabber_email,
    :password => jabber_password
  }
)

c.run
```

The first time a user communicates with Firejab, it will request an authentication token. If you would like to add one manually (for testing purposes), there's a public `add_token` method:

``` ruby
c.add_token(jabber_email, campfire_token)
```

TODO
-----

*  Persistent store of user authentication information
*  Support for multiple rooms or rooms defined by user
*  Verify that token is valid and lookup user data
   Eventually will probably have to make a CampfireUser class to handle this easily/gracefully
*  Make HTTP requests within EventMachine async
*  Presence notifications
*  Utility commands like /who
*  Properly handle subscription requests
*  Error handling/reconnects
*  Jabber disconnects when I send this: "I can probably dig up the old VB code... ;)"

Proposed Schema
-----

| jabber_username | campfire_token | campfire_uid | campfire_name |