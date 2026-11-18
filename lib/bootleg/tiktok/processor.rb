require "colorize"

module Bootleg
  module Tiktok
    class Processor
      def initialize(config)
        @config     = config
        @downloader = Downloader.new(config)
      end

      def process(url)
        puts "\n=> Processing: #{url}".cyan
        if UrlValidator.photo?(url)
          process_photo(url)
        else
          process_video(url)
        end
      end

      private

      def process_video(url)
        puts "  Trying HTML extraction...".blue
        data = HtmlExtractor.extract(url)

        if data
          puts "  HTML extraction succeeded".blue
        else
          puts "  Falling back to API...".yellow
          data = normalize_api_video(ApiClient.fetch(url))
        end

        @downloader.save_video(data, url)
      end

      def process_photo(url)
        puts "  Fetching photo post via API...".blue
        raw    = ApiClient.fetch(url)
        images = Array(raw["images"]).map(&:to_s).reject(&:empty?)
        raise "API returned no images for #{url}" if images.empty?

        @downloader.save_images(normalize_api_photo(raw), images, url)
      end

      def normalize_api_video(raw)
        video_url = api_video_url(raw)
        raise "API returned no video URL for post #{raw["id"]}" if video_url.to_s.empty?

        api_common(raw).merge(video_id: raw["id"].to_s, video_url: video_url)
      end

      def normalize_api_photo(raw)
        api_common(raw).merge(media_id: raw["id"].to_s)
      end

      def api_common(raw)
        author = raw["author"] || {}
        {
          author_id:   (author["uniqueId"] || author["username"]).to_s,
          author_name: author["nickname"].to_s,
          create_time: api_create_time(raw),
          description: raw["desc"].to_s,
          audio:       Audio.from(raw["music"], author["nickname"])
        }
      end

      # The API omits createTime, but a post id carries its creation time in the
      # high 32 bits, which matches the HTML path's createTime for every post in
      # the archive.
      def api_create_time(raw)
        return raw["createTime"].to_i if raw["createTime"]

        raw["id"].to_s.to_i >> 32
      end

      # Current deployments return the URL as a string; older ones nested it
      # under video.playAddr, sometimes as a list.
      def api_video_url(raw)
        video = raw["video"]
        return video if video.is_a?(String)

        addr = video.is_a?(Hash) ? video["playAddr"] : nil
        addr.is_a?(Array) ? addr.first : addr
      end
    end
  end
end
