##
# TOR proxy provider
##

require 'thread'
require 'anison-fucker/log'
require 'anison-fucker/proxy'


module AnisonFucker
  module Proxy
    module Tor
      # Launches tor service & checks it's state
      class ServiceWrapper
        # Tor installations available
        TOR_DEV  = File.realpath("#{File.dirname $0}/tor") rescue ''
        TOR_PROD = File.realpath("#{File.dirname File.realpath $0}/../lib/anison-fucker/libexec") rescue ''

        # Tor proxy params
        TOR_PROXY_HOST = '127.0.0.1'
        TOR_PROXY_PORT = 9050
        TOR_PROXY_TYPE = Type::SOCKS5

        # Set logger instance
        def initialize
          @log = Log.instance
          @ready = false
          @tor_pid = nil
          @ready_lock = nil
        end

        # Start tor service
        def start
          raise 'Tor is already started' if @tor_pid
          @ready_lock = Mutex.new
          Thread.new do
            @ready_lock.lock
            begin
              tor_binary = find_tor_binary
              IO.popen(tor_binary, err: [:child, :out]) do |tor_log_io|
                @tor_pid = tor_log_io.pid
                @log.info "Launching tor #{tor_binary} (pid: #{@tor_pid})"
                on_change = false
                loop do
                  message = tor_log_io.readline.strip
                  @log.debug('tor') { message }
                  if message =~ /Bootstrapped 100%/
                    @log.info 'Tor is ready!'
                    @ready_lock.unlock
                    @ready = true
                  elsif message =~ /Received reload signal/
                    @log.info 'Requesting a new tor exit node'
                    on_change = true
                    @ready_lock.lock unless @ready_lock.owned?
                  elsif message =~ /Configuration file ".+" not present, using reasonable defaults/ && on_change
                    @log.info 'Tor exit node changed'
                    on_change = false
                    @ready_lock.unlock
                  end
                end
              end
            rescue EOFError
              # ok, process completed
            rescue => e
              @log.error "Tor service error: #{e.message}"
            ensure
              @ready_lock.unlock if @ready_lock.owned?
            end
          end
          sleep 0.1
        end

        # Stop tor service
        def stop
          raise 'Tor is not started' unless @tor_pid
          Process.kill 'INT', @tor_pid
          Process.wait @tor_pid rescue nil
          sleep 0.1
          @ready = false
          @tor_pid = nil
        end

        # True if tor service is started
        def started?
          !!@tor_pid
        end

        # Switch to a new node
        def change_node
          raise 'Tor is not started' unless @tor_pid
          Process.kill 'HUP', @tor_pid
          sleep 0.1
        end

        # Execute associated block when tor is ready
        # Passes tor's proxy settings as an argument
        def on_ready
          raise 'Tor is not started!' unless @ready_lock
          settings = Settings.new TOR_PROXY_HOST, TOR_PROXY_PORT, TOR_PROXY_TYPE
          @ready_lock.synchronize { @ready ? yield(settings) : raise('Tor failed!') }
        end

        private

        # Try to find tor binary to launch
        def find_tor_binary
          paths = [TOR_DEV, TOR_PROD]
          paths += `whereis tor`.split(/\s+/).select { |p| p=~ %r`/bin/` }
          paths.each do |path|
            return path if File.exist? path
          end
          raise 'No tor found!'
        end
      end

      # Tor proxy provider
      class TorProxyProvider < ProxyProvider
        # Set tor service
        #   service   ServiceWrapper
        def initialize(service = nil)
          @tor = service || ServiceWrapper.new
        end

        # Get next proxy when ready
        def next_proxy
          if @tor.started?
            @tor.change_node
          else
            @tor.start
          end
          # TODO: Check if external IP really changed
          @tor.on_ready { |settings| return settings }
        end

        # Stop tor service
        def stop_tor
          @tor.stop if @tor.started?
        end
      end
    end
  end
end
