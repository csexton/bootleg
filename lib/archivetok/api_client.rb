require "net/http"
require "uri"
require "json"
require "colorize"
require_relative "ssl_helper"

module Archivetok
  # Fallback metadata source, used when the rehydration JSON embedded in the
  # page HTML cannot be parsed. It is also the only source for photo posts,
  # whose images the HTML extractor does not handle.
  module ApiClient
    extend SslHelper

    API_URL   = "https://api-tiktok-downloader.vercel.app/api/download"
    MOBILE_UA = "TikTok 26.2.0 rv:262018 (iPhone; iOS 14.4.2; en_US) Cronet"

    # Returns the decoded payload for a post, raising on anything unusable.
    def self.fetch(url)
      uri       = URI.parse(API_URL)
      uri.query = URI.encode_www_form(url: url)

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = MOBILE_UA
      req["Accept"]     = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 cert_store: ssl_store,
                                 open_timeout: 15, read_timeout: 60) do |http|
        http.request(req)
      end

      raise "API HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

      payload(response.body, url)
    end

    def self.payload(body, url)
      data = JSON.parse(body)
      raise "API response was not an object for #{url}" unless data.is_a?(Hash)

      unless data["status"] == "success"
        detail = data["message"] || data["status"]
        raise "API returned #{detail.inspect} for #{url}"
      end

      # Older deployments wrapped the post under "result"; current ones return
      # its fields at the top level.
      data["result"].is_a?(Hash) ? data["result"] : data
    rescue JSON::ParserError => e
      raise "API returned invalid JSON for #{url}: #{e.message}"
    end
  end
end
