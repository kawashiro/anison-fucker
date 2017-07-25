##
# Main implementation of anison-fucker app
##

require 'curl'
require 'anison-fucker/proxy/tor'


module AnisonFucker
  class Application
    # Run application
    def run
      # TODO: Implement
      Log.instance.info 'tor proxy test ...'
      proxy_provider = Proxy::Tor::TorProxyProvider.new
      loop do
        proxy = proxy_provider.next_proxy
        curl = Curl::Easy.new 'http://ifconfig.co/'
        curl.proxy_type = proxy.type
        curl.proxy_url = proxy.url
        curl.headers['User-Agent'] = 'curl/1.0.0'
        curl.perform
        Log.instance.info('curl') { curl.body_str }
        sleep 5
      end
    rescue Interrupt
      Log.instance.info 'Interrupted!'
    ensure
      proxy_provider.stop_tor
    end
  end
end
