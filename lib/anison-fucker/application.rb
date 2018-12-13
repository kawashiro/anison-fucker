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
    #   delta     Integer
    def self.run(song_id, delta)
      log = Log.instance
      tor_service_wrapper = Proxy::Tor::ServiceWrapper.new

      raise 'Invalid song ID provided' unless song_id > 0
      raise 'Invalid additional votes number provided' unless delta > 0

      Remote::Anison.captcha_resolver = Captcha::ManualResolver.new
      Remote::Anison.mail_service = Remote::TemporaryMail.new
      Remote::Anison.proxy_provider = Proxy::Tor::TorProxyProvider.new tor_service_wrapper
      Remote::Anison.user_agent_provider = Remote::RemoteUserAgentList.new
      Remote::Anison.credentials_provider = Remote::AnisonCredentialsList.new

      was_on_top = false
      loop do
        votes_to_do = 0
        is_in_queue = false
        Remote::Anison.guest_session do |anison|
          status = anison.get_status song_id
          top_song_votes = status[:top_song_status][:votes].to_i
          my_song_votes = status[:my_song_status] ? status[:my_song_status][:votes].to_i : 0
          votes_to_do = top_song_votes - my_song_votes + delta
          is_in_queue = !!status[:my_song_status]
        end

        break if was_on_top && !is_in_queue

        was_on_top ||= is_in_queue && votes_to_do == 0

        log.info "#{votes_to_do} votes to be done!"

        Remote::Anison.session votes_to_do do |anison|
          log.info "Voting for song \##{song_id} as #{anison.login}"
          begin
            anison.vote song_id
            log.info 'Voted successfully!'
          rescue Remote::Anison::VoteError => e
            log.warn "Failed to vote as #{anison.login}: #{e.message}"
          end
        end

        sleep 10 if votes_to_do == 0
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
