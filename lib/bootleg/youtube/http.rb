require "net/http"
require "uri"
require "json"
require_relative "../ssl_helper"

module Bootleg
  module Youtube
    # A failed call to a Google endpoint. `reason` is Google's machine-readable
    # reason ("quotaExceeded", "invalid_grant", ...) when the body had one.
    class ApiError < Error
      attr_reader :status, :reason

      QUOTA_REASONS = %w[quotaExceeded uploadLimitExceeded dailyLimitExceeded].freeze

      def self.from(response, context = nil)
        reason, detail = parse(response.body)
        message = ["#{context || "YouTube API"} failed (HTTP #{response.code})", detail || reason]
                  .compact.join(": ")
        new(message, status: response.code, reason: reason)
      end

      # Data API errors nest under error.errors[]; OAuth errors are flat.
      def self.parse(body)
        data = JSON.parse(body.to_s)
        return [nil, nil] unless data.is_a?(Hash)

        error = data["error"]
        if error.is_a?(Hash)
          [Array(error["errors"]).first&.fetch("reason", nil), error["message"]]
        else
          [error, data["error_description"]]
        end
      rescue JSON::ParserError
        [nil, nil]
      end

      def initialize(message, status: nil, reason: nil)
        super(message)
        @status = status
        @reason = reason
      end

      def quota?
        QUOTA_REASONS.include?(reason)
      end
    end

    Response = Struct.new(:code, :headers, :body) do
      def success?
        code.between?(200, 299)
      end

      def [](name)
        headers[name.downcase]
      end

      def json
        body.to_s.empty? ? {} : JSON.parse(body)
      end
    end

    # The one place that talks to the network, so specs can swap in a fake.
    class Http
      include SslHelper

      def request(method, url, headers: {}, body: nil)
        uri = URI.parse(url)
        req = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
        headers.each { |k, v| req[k] = v }
        req.body = body if body

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                              cert_store: ssl_store, open_timeout: 15, read_timeout: 300) do |http|
          http.request(req)
        end

        Response.new(res.code.to_i, res.each_header.to_h, res.body.to_s)
      end
    end
  end
end
