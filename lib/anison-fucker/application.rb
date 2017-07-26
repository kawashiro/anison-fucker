##
# Main implementation of anison-fucker app
##

require 'anison-fucker/captcha'
require 'anison-fucker/log'
require 'anison-fucker/remote/anison'
require 'anison-fucker/remote/mail'
require 'anison-fucker/remote/user-agent'
require 'anison-fucker/proxy/tor'


module AnisonFucker
  module Application
    # Run application
    #   song_id   Integer
    def self.run(song_id)
      log = Log.instance
      tor_service_wrapper = Proxy::Tor::ServiceWrapper.new

      raise 'Invalid song ID provided' unless song_id > 0

      Remote::Anison.captcha_resolver = Captcha::ManualResolver.new
      Remote::Anison.mail_service = Remote::TemporaryMail.new
      Remote::Anison.proxy_provider = Proxy::Tor::TorProxyProvider.new tor_service_wrapper
      Remote::Anison.user_agent_provider = Remote::RemoteUserAgentList.new
      Remote::Anison.credentials_provider = Remote::AnisonCredentialsList.new

      # TODO: Monitor required sessions count
      Remote::Anison.session 20 do |anison|
        log.info "Voting for song \##{song_id} as #{anison.login}"
        begin
          anison.vote song_id
          log.info 'Voted successfully!'
        rescue Remote::Anison::VoteError => e
          log.warn "Failed to vote as #{anison.login}: #{e.message}"
        end
      end

    rescue Interrupt
      log.warn 'Interrupted!'
    rescue => e
      log.error "Failed to move your song to the top: #{e.message}"
    ensure
      tor_service_wrapper.stop if tor_service_wrapper.started?
    end
  end
end
