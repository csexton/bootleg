require_relative "ssl_helper"
require_relative "config_file"
require_relative "tiktok/page_fetcher"
require_relative "tiktok/config"
require_relative "tiktok/url_validator"
require_relative "tiktok/audio"
require_relative "tiktok/html_extractor"
require_relative "tiktok/api_client"
require_relative "tiktok/downloader"
require_relative "tiktok/processor"
require_relative "tiktok/profile_extractor"
require_relative "tiktok/cli"

module Subetha
  # TikTok as a source: download videos and photo posts with metadata
  # sidecars, and list the posts on a profile.
  module Tiktok
  end
end
