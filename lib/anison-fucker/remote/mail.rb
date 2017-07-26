##
# Temporary email service
##

require 'json'
require 'nokogiri'
require 'anison-fucker/remote'
require 'anison-fucker/utils'


module AnisonFucker
  module Remote
    class TemporaryMail < RemoteService
      include Utils

      # Service base URL
      BASE_URL = 'https://10minutemail.com/10MinuteMail'

      # Init internal state
      #   user_agent   String
      #   proxy        Proxy::Settings
      def initialize(user_agent = nil, proxy = nil)
        super
        @mail_index = 0
        @session = nil
      end

      # Create inbox and start monitoring it
      def create_inbox
        @session = nil
        @mail_index = 0
        headers = fetch_url_curl('/index.html').header_str
        @session = headers[/JSESSIONID=(.+?);/, 1]
        real_loc = headers[/Location:\s+#{BASE_URL}(.+?)\s/, 1]
        Nokogiri::HTML(fetch_url real_loc).css('input#mailAddress').attribute('value').to_s
      end

      # Call associated block when new email is received
      def on_new_email
        raise 'No active inbox created' unless @session
        loop do
          emails = JSON.parse fetch_url "/resources/messages/messagesAfter/#{@mail_index}"
          @mail_index += emails.size
          emails.each { |mail| yield keys_to_sym mail }
          fetch_url '/resources/session/reset'
          sleep 5
        end
        @session = nil
        @mail_index = 0
      end

      protected

      # Simple GET or POST request
      #   url   String
      #   body  String
      def fetch_url_curl(url, body = nil)
        super "#{BASE_URL}#{url}", body do |curl|
          curl.headers['Cookie'] = "JSESSIONID=#{@session};" if @session
        end
      end
    end
  end
end
