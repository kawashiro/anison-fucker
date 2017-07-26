##
# Real IP checker
##

require 'json'
require 'anison-fucker/remote'
require 'anison-fucker/utils'


module AnisonFucker
  module Remote
    class IPChecker < RemoteService
      include Utils

      # Checker URL
      CHECKER_URL = 'http://ifconfig.co/json'

      # Get remote IP address detailed info
      def get_ip_info
        keys_to_sym JSON.parse fetch_url CHECKER_URL
      end
    end
  end
end
