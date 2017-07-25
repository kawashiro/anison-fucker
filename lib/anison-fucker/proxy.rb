##
# Base proxy support implementation
##

module AnisonFucker
  module Proxy
    # Proxy types supported
    # see: /usr/include/curl/curl.h
    module Type
      HTTP     = 0
      HTTP_1_0 = 1
      SOCKS4   = 4
      SOCKS5   = 5
      SOCKS4A  = 6
    end

    # Proxy settings container
    class Settings
      attr_reader :host
      attr_reader :port
      attr_reader :type

      # Set proxy parameters
      #   host    String
      #   port    Integer
      #   type    Integer
      def initialize(host, port, type = Type::HTTP)
        @host = host
        @port = port
        @type = type
      end

      # Get host + port (url-like)
      def url
        "#{host}:#{port}"
      end
    end

    # Proxies provider
    class ProxyProvider
      # Get next proxy when ready
      def next_proxy
        raise 'Not implemented'
      end
    end
  end
end
