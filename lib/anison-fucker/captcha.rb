##
# Captcha resolvers
##


module AnisonFucker
  module Captcha
    # Abstract resolver
    class Resolver
      # Resolve captcha using image data
      def resolve(image_data)
        raise 'Not implemented'
      end
    end

    # Resolves captcha manually
    class ManualResolver < Resolver
      # Resolve captcha using image data
      def resolve(image_data)
        tmp_path = "/tmp/#{Random.srand}.png"
        File.open(tmp_path, 'w') { |f| f.write image_data }
        pid = fork { exec "feh -B white #{tmp_path}" }
        print 'Captcha: '
        $stdin.gets.strip
      ensure
        Process.kill 'INT', pid rescue nil
        Process.wait pid rescue nil
        File.unlink tmp_path if File.exist? tmp_path
      end
    end
  end
end
