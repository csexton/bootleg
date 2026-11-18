require "json"

module Bootleg
  module Youtube
    # The handful of YouTube Data API v3 calls bootleg needs.
    class Client
      API_URL    = "https://www.googleapis.com/youtube/v3".freeze
      UPLOAD_URL = "https://www.googleapis.com/upload/youtube/v3/videos".freeze
      # Resumable chunks must be a multiple of 256 KiB.
      CHUNK_SIZE  = 8 * 1024 * 1024
      MAX_RETRIES = 5
      RETRYABLE   = [500, 502, 503, 504].freeze
      NETWORK_ERRORS = [IOError, SystemCallError, SocketError, Timeout::Error,
                        OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout].freeze

      def initialize(auth, http: Http.new, sleeper: ->(s) { sleep s })
        @auth    = auth
        @http    = http
        @sleeper = sleeper
      end

      # Uploads a video with the given videos.insert body (snippet + status),
      # yielding (bytes_sent, total) as chunks land. Returns the video resource.
      def insert_video(path, metadata, &progress)
        total = File.size(path)
        raise Error, "#{path} is empty" if total.zero?

        res = authorized(:post, "#{UPLOAD_URL}?uploadType=resumable&part=#{parts(metadata)}",
                         headers: { "Content-Type"            => "application/json; charset=UTF-8",
                                    "X-Upload-Content-Type"   => "video/*",
                                    "X-Upload-Content-Length" => total.to_s },
                         body:    JSON.generate(metadata))
        raise ApiError.from(res, "Starting the upload") unless res.success?

        session = res["location"]
        raise Error, "YouTube did not return an upload session" if session.to_s.empty?

        upload_chunks(session, path, total, &progress)
      end

      def list_videos(ids, part: "snippet")
        return [] if ids.empty?

        query = URI.encode_www_form(part: part, id: ids.join(","))
        res = authorized(:get, "#{API_URL}/videos?#{query}")
        raise ApiError.from(res, "Listing videos") unless res.success?

        res.json["items"] || []
      end

      def update_video(resource, part: "snippet")
        res = authorized(:put, "#{API_URL}/videos?part=#{part}",
                         headers: { "Content-Type" => "application/json; charset=UTF-8" },
                         body:    JSON.generate(resource))
        raise ApiError.from(res, "Updating video #{resource[:id] || resource["id"]}") unless res.success?

        res.json
      end

      private

      def parts(metadata)
        metadata.keys.map(&:to_s).join(",")
      end

      def upload_chunks(session, path, total)
        offset  = 0
        retries = 0
        File.open(path, "rb") do |file|
          loop do
            file.seek(offset)
            chunk = file.read(CHUNK_SIZE)
            res   = send_chunk(session, chunk, offset, total)

            if res&.success?
              yield total, total if block_given?
              return res.json
            elsif res&.code == 308
              offset  = next_offset(res)
              retries = 0
              yield offset, total if block_given?
            elsif res.nil? || RETRYABLE.include?(res.code)
              retries += 1
              raise ApiError.from(res, "Uploading #{File.basename(path)}") if res && retries > MAX_RETRIES
              raise Error, "Upload of #{File.basename(path)} kept failing" if retries > MAX_RETRIES

              @sleeper.call(2**retries)
              status = upload_status(session, total)
              return status.json if status&.success?

              offset = next_offset(status) if status&.code == 308
            else
              raise ApiError.from(res, "Uploading #{File.basename(path)}")
            end
          end
        end
      end

      def send_chunk(session, chunk, offset, total)
        last = offset + chunk.bytesize - 1
        authorized(:put, session,
                   headers: { "Content-Length" => chunk.bytesize.to_s,
                              "Content-Range"  => "bytes #{offset}-#{last}/#{total}" },
                   body:    chunk)
      rescue *NETWORK_ERRORS
        nil
      end

      # Asks the session how much it has, after an interrupted chunk.
      def upload_status(session, total)
        authorized(:put, session, headers: { "Content-Length" => "0",
                                             "Content-Range"  => "bytes */#{total}" },
                                  body:    "")
      rescue *NETWORK_ERRORS
        nil
      end

      # 308 carries "Range: bytes=0-N" for what has been stored so far.
      def next_offset(res)
        range = res["range"].to_s[/\d+-(\d+)/, 1]
        range ? range.to_i + 1 : 0
      end

      # Sends a request with the bearer token, refreshing once on a 401.
      def authorized(method, url, headers: {}, body: nil)
        res = @http.request(method, url, headers: headers.merge(bearer), body: body)
        return res unless res.code == 401

        @auth.refresh!
        @http.request(method, url, headers: headers.merge(bearer), body: body)
      end

      def bearer
        { "Authorization" => "Bearer #{@auth.access_token}" }
      end
    end
  end
end
