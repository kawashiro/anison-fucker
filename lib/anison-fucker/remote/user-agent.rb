##
# Remote user agent list fetch
##

require 'anison-fucker/log'
require 'anison-fucker/remote'


module AnisonFucker
  module Remote
    # Get random user agent from remote list
    class RemoteUserAgentList < UserAgentList
      # Set logger & remote service
      #   list_service    UserAgentListService
      def initialize(list_service = nil)
        @log = Log.instance
        @list_service = list_service || UserAgentListService.new
        @user_agents = []
      end

      # Get next user agent string
      def next
        if @user_agents.empty?
          @log.info 'Refreshing user agents list'
          @user_agents = @list_service.get_user_agents.shuffle
          @log.info "Fetched #{@user_agents.size} new user agents"
        end
        @user_agents.shift
      end
    end

    # Remote service to fetch user agents
    class UserAgentListService < RemoteService
      # User agents list URL
      USER_AGENTS_LIST_URL = 'https://bit.ly/2zW01Or'

      # Get all remote user agents
      def get_user_agents
        txt_data = fetch_url USER_AGENTS_LIST_URL
        txt_data.split("\n").map(&:strip)
      end
    end
  end
end
