##
# Fetch random names
##

require 'json'
require 'nokogiri'
require 'uri'
require 'anison-fucker/remote'


module AnisonFucker
  module Remote
    class NamesFetcher < RemoteService

      # Names HTML page URL
      NAMES_URL = 'http://listofrandomnames.com/index.cfm?generated'

      # Get names list
      def get_random_names
        form_data = {action: 'main.generate', allit: 1, fnameonly: 1, nameType: 'na', numberof: 50}
        response = fetch_url NAMES_URL, URI.encode_www_form(form_data)
        Nokogiri::HTML(response).css('a.firstname').map { |el| el.text.strip.downcase }
      end
    end
  end
end
