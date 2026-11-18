require "json"

module Bootleg
  module Youtube
    # Titles of the newest Shorts on a channel (about 48), newest first,
    # scraped from the public Shorts tab, so no login or quota is needed.
    class ShortsLister
      USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                   "(KHTML, like Gecko) Chrome/130 Safari/537.36".freeze
      MAX_REDIRECTS = 3
      ITEM = /"accessibilityText":"((?:[^"\\]|\\.)*?play Short)"/
      # "<title>, 1.2K views - play Short"
      SUFFIX = /, [\d.,]*\s*[A-Za-z]*\s*views? - play Short\z/

      def self.titles(handle, http: Http.new)
        new(http).titles(handle)
      end

      def initialize(http)
        @http = http
      end

      def titles(handle)
        handle = handle.to_s.strip
        raise Error, "No channel handle given" if handle.empty?

        handle = "@#{handle}" unless handle.start_with?("@")
        parse(fetch("https://www.youtube.com/#{handle}/shorts"))
      end

      def parse(html)
        html.scan(ITEM).map do |(text)|
          JSON.parse(%("#{text}")).sub(SUFFIX, "")
        end
      end

      private

      def fetch(url, redirects = 0)
        res = @http.request(:get, url, headers: { "User-Agent"      => USER_AGENT,
                                                  "Accept-Language" => "en-US" })
        if (300..399).cover?(res.code) && res["location"] && redirects < MAX_REDIRECTS
          return fetch(URI.join(url, res["location"]).to_s, redirects + 1)
        end
        raise Error, "YouTube returned HTTP #{res.code} for #{url}" unless res.success?

        res.body
      end
    end
  end
end
