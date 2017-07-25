##
# Global logger implementation
##

require 'colorize'
require 'logger'
require 'singleton'


module AnisonFucker
  class Log
    include Singleton

    # Set up system-wide logger instance
    # noinspection RubyResolve
    def initialize
      @logger = Logger.new $>
      @logger.formatter = proc do |severity, datetime, progname, msg|
        full_msg = "[#{severity[0]}] #{datetime.strftime '%F %T'} :: #{progname ? "[#{progname}] " : ''}#{msg}#{$/}"
        case severity.to_sym
          when :DEBUG
            full_msg.light_black
          when :INFO
            full_msg.black
          when :WARN
            full_msg.yellow
          when :ERROR
            full_msg.red
          when :FATAL
            full_msg.red.bold
          else
            full_msg
        end
      end
    end

    # Pass unknown calls to internal logger
    #   meth    Symbol
    #   args    Array
    #   block   Proc
    def method_missing(meth, *args, &block)
      @logger.method(meth).call *args, &block
    end
  end
end
