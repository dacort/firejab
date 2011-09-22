require 'twitter/json_stream'
require 'xmpp4r-simple'
require 'yajl'
require 'typhoeus'

module Firejab
  class Connection
    attr_accessor :be_noisy
    attr_accessor :campfire, :campfire_uids, :campfire_options, :campfire_domain, :campfire_room_id
    attr_accessor :jabber, :jabber_users

    def initialize(params)
      self.jabber = Jabber::Simple.new(params[:jabber][:username], params[:jabber][:password])

      self.campfire_options = {
        :path => "/room/#{params[:room_id]}/live.json",
        :host => 'streaming.campfirenow.com',
        :auth => "#{params[:token]}:x"
      }
      self.campfire_room_id = params[:room_id]
      self.campfire_domain = params[:domain]
      self.be_noisy = false

      # Load known tokens for our users from a "database"
      self.jabber_users = {}
      self.campfire_uids = {}
    end

    def add_token(jabber_username, campfire_token)
      self.jabber_users[jabber_username] ||= {}
      self.jabber_users[jabber_username][:campfire_token] = campfire_token
    end

    def run
      EM.run do
        self.campfire = Twitter::JSONStream.connect(self.campfire_options)

        # Tell us what to do when we receive a campfire message
        self.campfire.each_item do |item|
          puts "Received a new message from campfire: #{item}"
          status = Yajl::Parser.parse(item)
          # For ppl that are connected and(?) we have tokens for, send the msg
          case status["type"]
          when "TextMessage", "PasteMessage"
            send_message_to_jabber_users(status['user_id'], status['body'])
          when "UploadMessage"
            #TODO: Retrieve full URL from `GET /room/#{id}/messages/#{upload_message_id}/upload.json`
            send_message_to_jabber_users(status['user_id'], "Uploaded #{status['body']}")
          when "EnterMessage"
            send_message_to_jabber_users(status['user_id'], "Has entered the room!") if self.be_noisy
          when "LeaveMessage", "KickMessage"
            send_message_to_jabber_users(status['user_id'], "Has left the room.") if self.be_noisy
          end
        end

        self.campfire.on_error do |message|
          puts "Received a campfire error: #{message}"
        end

        self.campfire.on_max_reconnects do |timeout, retries|
          puts "Fatal error with campfire, you'll need to restart"
        end

        EM::PeriodicTimer.new(1) do
          check_jabber_connection

          self.jabber.received_messages do |message|
            # Removes "/resource"
            jabber_username = message.from.strip

            if is_valid_user(jabber_username)
              send_message_to_campfire(jabber_username, message.body)
            elsif message.body.match(/^\w{40}$/)
              # We received an auth token
              add_token(jabber_username, message.body)
              #TODO: Verify token and lookup_campfire_uid
              send_jabber_message(jabber_username, "Heloooooo!")
            else
              # We don't know who this is, ask for their token
              send_jabber_message(jabber_username, "Hi! I don't know who you are, please send me your auth token from: https://#{self.campfire_domain}/member/edit")
            end
          end

          self.jabber.presence_updates do |friend, presence, message|
            # presence may be one of [:online, :unavailable, :away]
            # puts "Received presence update from #{friend.inspect}: #{presence.inspect} => #{message.inspect}"
            #TODO: Update room presence accordingly - POST /room/#{id}/[join,leave].json
            set_status(friend, presence)
          end

          self.jabber.new_subscriptions do |friend, presence|
            puts "New subscription request: #{friend.inspect}"
            # self.jabber.add(friend['jid'])
          end
        end
      end
    end

    private
      def is_valid_user(jabber_username)
        !(self.jabber_users[jabber_username].nil? or self.jabber_users[jabber_username][:campfire_token].nil?)
      end

      def check_jabber_connection
        if !self.jabber.connected?
          puts "Reconnecting to Jabber"
          self.jabber.reconnect 
        end
      end

      def send_jabber_message(jid, message)
        # TODO: Possibly make sure format is correct here
        self.jabber.deliver(jid, message)
      end

      def send_message_to_jabber_users(from_uid, message)
        self.jabber_users.each do |jid, jid_info|
          next if jid_info[:status] == :unavailable
          next if jid_info[:campfire_uid] == from_uid rescue false

          send_jabber_message(jid, "#{campfire_name(from_uid)}: #{message}")
        end
      end

      def send_message_to_campfire(from_jid, message)
        jabber_username = from_jid.to_s.split("/").first
        campfire_token  = lookup_token(jabber_username)
        #TODO: raise an error if nil

        response = Typhoeus::Request.post("https://#{self.campfire_domain}/room/#{self.campfire_room_id}/speak.json", 
          :body => Yajl::Encoder.encode({:message => {:body => message}}),
          :username => campfire_token, :password => "x",
          :headers => {"Content-type" => "application/json"}
        )

        campfire_uid = Yajl::Parser.parse(response.body)['message']['user_id']
        set_campfire_uid_on_jabber_user(jabber_username, campfire_uid)
      end


      def lookup_token(jabber_username)
        self.jabber_users[jabber_username][:campfire_token] rescue nil
      end

      def set_status(jabber_username, status)
        self.jabber_users[jabber_username] ||= {}
        self.jabber_users[jabber_username][:status] = status
      end

      def set_campfire_uid_on_jabber_user(jabber_username, campfire_uid)
        self.jabber_users[jabber_username] ||= {}
        self.jabber_users[jabber_username][:campfire_uid] = campfire_uid
      end

      def campfire_name(campfire_uid)
        self.campfire_uids[campfire_uid] ||= Yajl::Parser.parse(
          Typhoeus::Request.get("https://#{self.campfire_domain}/users/#{campfire_uid}.json",
            :username => self.campfire_options[:auth].split(":").first, :password => "x"
          ).body
        )['user']

        self.campfire_uids[campfire_uid]['name']
      end

  end
end