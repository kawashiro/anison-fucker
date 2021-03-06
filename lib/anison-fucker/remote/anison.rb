##
# Integration with anison
##

require 'json'
require 'nokogiri'
require 'uri'
require 'anison-fucker/log'
require 'anison-fucker/remote'
require 'anison-fucker/remote/ip-checker'
require 'anison-fucker/remote/names-fetcher'
require 'anison-fucker/utils'


module AnisonFucker
  module Remote
    # Main anison service class
    class Anison < RemoteService
      include Utils

      attr_reader :login

      # Base url
      BASE_URL = 'http://anison.fm'

      # Init internal state
      #   user_agent   String
      #   proxy        Proxy::Settings
      def initialize(user_agent = nil, proxy = nil)
        super
        @auth_cookies = nil
        @login = nil
      end

      # Authorize as user
      #   login     String
      #   password  String
      def authorize(login, password)
        form_data = {login: login, password: password, authform: 'Логин'}
        login_curl = fetch_url_curl '/user/login', URI.encode_www_form(form_data)
        login_result_page = login_curl.body_str.force_encoding 'UTF-8'
        error = Nokogiri::HTML(login_result_page).css('div.anime_blocked').text
        raise AuthError.new "Failed to log in anison.fm as #{login}: #{error}" unless error.empty?

        headers = login_curl.header_str
        session_id = headers[/session_id=(\d+?);/, 1]
        php_session = headers[/PHPSESSID=([0-9a-f]+?);/, 1]
        session_hash = headers[/session_hash=([0-9a-f]+?);/, 1]
        @auth_cookies = "PHPSESSID=#{php_session}; session_linking=0; session_id=#{session_id}; session_hash=#{session_hash}"
        @login = login
      end

      # Register a new account
      #   login     String
      #   password  String
      #   email     String
      def register(login, password, email)
        register_page_curl = fetch_url_curl '/user/join'
        register_page = register_page_curl.body_str
        headers = register_page_curl.header_str
        php_session = headers[/PHPSESSID=([0-9a-z]+?);/, 1]
        @auth_cookies = "PHPSESSID=#{php_session}"

        captcha_url = Nokogiri::HTML(register_page).css('img[src^="/captcha"]').attribute('src').to_s
        captcha_data = fetch_url captcha_url
        captcha_text = yield captcha_data
        form_data = {login: login, password: password, email: email, code: captcha_text, authform: 'Регистрация'}
        submitted_page = fetch_url '/user/join', URI.encode_www_form(form_data)

        success = Nokogiri::HTML(submitted_page).css('div.restore_success').text
        raise RegistrationError.new "Something went wrong registering user #{login}<#{email}>" if success.empty?
      end

      # Confirm email
      #   token   String
      def confirm_email(token)
        page = fetch_url "/user/join-confirm?token=#{token}"
        success = Nokogiri::HTML(page).css('div.restore_success').text
        raise EmailConfirmError.new "Something went wrong confirming e-mail (token: #{token})" if success.empty?
      end

      # Add vote for the song
      #   song_id   Integer
      def vote(song_id)
        form_data = {action: 'up', song: song_id, premium: 0, comment: ''}
        response = fetch_url '/song_actions.php', URI.encode_www_form(form_data)
        error = response =~ /<div class='error'>/
        if error
          error_message = response.sub(/^.*?>/, '').sub(/<.*$/, '')
          raise VoteError.new "Unable to vote for the song \##{song_id}: #{error_message}"
        end
      end

      # Get current songs queue
      def get_status(song_id)
        status = JSON.parse fetch_url '/status.php'
        top_song_status = keys_to_sym status['orders_list'].reject { |st| st['song_id'].to_i == song_id }.first
        my_song_status = status['orders_list'].select { |st| st['song_id'].to_i == song_id }.first
        my_song_status = keys_to_sym my_song_status if my_song_status

        { top_song_status: top_song_status, my_song_status: my_song_status }
      end

      protected

      # Hack with encoding
      #   url   String
      #   body  String
      def fetch_url(url, body = nil)
        str = super
        str.force_encoding 'UTF-8' rescue str
      end

      # Simple GET or POST request
      #   url   String
      #   body  String
      def fetch_url_curl(url, body = nil)
        super "#{BASE_URL}#{url}", body do |curl|
          curl.headers['Cookie'] = @auth_cookies if @auth_cookies
          curl.headers['Referer'] = BASE_URL
        end
      end

      # Error cases
      class AuthError < RuntimeError; end
      class RegistrationError < RuntimeError; end
      class EmailConfirmError < RuntimeError; end
      class VoteError < RuntimeError; end
    end

    # Metaclass for sessions manipulation
    class << Anison
      # Start authorized session(s)
      #   times   Integer
      def session(times = 1)
        log = Log.instance
        loop do
          break if times <= 0
          times -= 1

          log.info 'Starting new anison session'
          proxy_settings = @proxy_provider.next_proxy
          user_agent = @user_agent_provider.next
          login, password = @credentials_provider.next
          ip = IPChecker.new(user_agent, proxy_settings).get_ip_info

          log.info "PROXY: #{proxy_settings.url}"
          log.info "UA:    #{user_agent}"
          log.info "LOGIN: #{login}"
          log.info "IP:    #{ip[:query]} (#{ip[:country]})"
          anison = new user_agent, proxy_settings
          begin
            should_register = false
            anison.authorize login, password
          rescue Anison::AuthError
            should_register = true
          end

          if should_register
            log.info "Looks like user #{login} does not exist, registering"
            email = @mail_service.create_inbox
            log.info "EMAIL: #{email}"
            anison.register login, password, email do |captcha|
              @captcha_resolver.resolve captcha
            end
            log.info 'Awaiting for confirmation e-mail'
            @mail_service.on_new_email do |mail|
              token = mail[:bodyPlainText][%r`попробуйте ввести код \(([0-9a-z]+)\) вручную`i, 1]
              next if !token || token.empty?
              log.info "Got e-mail token: #{token}"
              anison.confirm_email token
              break
            end
            anison.authorize login, password
            @credentials_provider.save_login! login
          end

          yield anison
        end
      end

      # No auth, just view public content
      def guest_session
        yield new
      end

      # Set captcha resolver
      #   resolver    Captcha::Resolver
      def captcha_resolver=(resolver)
        @captcha_resolver = resolver
      end

      # Set mail service
      def mail_service=(mail_service)
        @mail_service = mail_service
      end

      # Set proxy provider
      #   proxy_provider    Proxy::ProxyProvider
      def proxy_provider=(proxy_provider)
        @proxy_provider = proxy_provider
      end

      # Set user agent list provider
      #   ua_provider   UserAgentList
      def user_agent_provider=(ua_provider)
        @user_agent_provider = ua_provider
      end

      # Set credentials provider
      #   credentials_provider    CredentialsList
      def credentials_provider=(credentials_provider)
        @credentials_provider = credentials_provider
      end
    end

    # Fixed credentials list
    class AnisonCredentialsList
      # Logins prefix
      LOGIN_MASK = '%s%03d'

      # Fixed password
      PASSWORD = 'qweqwe'

      LOGINS_FILE = "#{ENV['HOME']}/.anison-logins.txt"

      # # Set account init number
      def initialize
        @known_logins = nil
        @unknown_logins = []
      end

      # Get next credentials pair
      def next
        unless @known_logins
          known_logins = []
          if File.exist? LOGINS_FILE
            File.open LOGINS_FILE do |f|
              known_logins = f.readlines.map(&:strip).reject(&:empty?)
            end
          end
          @known_logins = known_logins.shuffle
        end

        if @known_logins.empty?
          if @unknown_logins.empty?
            names = NamesFetcher.new.get_random_names
            logins = names.map { |n| LOGIN_MASK % [n, Random.rand(999)] }
            @unknown_logins = logins
          end
          login = @unknown_logins.shift
        else
          login = @known_logins.shift
        end

        [login, PASSWORD]
      end

      # save login as successfully registered
      #   login   String
      def save_login!(login)
        File.open(LOGINS_FILE, 'a') { |f| f << login << "\n" }
      end
    end
  end
end
