##
# Base remote services integration
##

require 'curl'
require 'thread'


module AnisonFucker
  module Remote
    class RemoteService
      # User agent if no custom provided, not recommended for usage
      DEFAULT_USER_AGENT = 'AnisonFucker/0.0.1'

      attr_writer :proxy
      attr_writer :user_agent

      # Init internal state
      #   user_agent   String
      #   proxy        Proxy::Settings
      def initialize(user_agent = nil, proxy = nil)
        @proxy = proxy
        @user_agent = user_agent || DEFAULT_USER_AGENT
      end

      protected

      # Simple GET or POST request
      #   url   String
      #   body  String
      def fetch_url(url, body = nil)
        fetch_url_curl(url, body).body_str
      end

      # Simple GET or POST request, return curl handler instead of response body
      #   url   String
      #   body  String
      def fetch_url_curl(url, body = nil)
        verb = body ? :POST : :GET
        Thread.current[:curb_curl] = nil
        Curl.http verb, url, body do |curl|
          if @proxy
            curl.proxy_type = @proxy.type
            curl.proxy_url = @proxy.url
          end
          curl.headers['User-Agent'] = @user_agent
          curl.follow_location = true
          # curl.verbose = true
          yield curl if block_given?
        end
      end
    end

    # Abstract user agent list provider
    class UserAgentList
      # Get next user agent string
      def next
        raise 'Not implemented'
      end
    end
  end
end
