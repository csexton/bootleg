require "digest"
require "fileutils"
require "json"
require "securerandom"
require "socket"
require "uri"

module Subetha
  module Youtube
    # OAuth for an installed (desktop) app: a browser login that redirects to
    # a one-shot server on 127.0.0.1, then a refresh token kept on disk.
    class Auth
      SCOPES = [
        "https://www.googleapis.com/auth/youtube.upload",
        # Needed to edit already-uploaded videos (update-descriptions).
        "https://www.googleapis.com/auth/youtube.force-ssl"
      ].freeze
      AUTH_URI      = "https://accounts.google.com/o/oauth2/auth".freeze
      TOKEN_URI     = "https://oauth2.googleapis.com/token".freeze
      LOGIN_TIMEOUT = 300
      # Refresh a little early so a token doesn't expire mid-request.
      EXPIRY_MARGIN = 60

      def initialize(config, http: Http.new, out: $stderr)
        @config = config
        @http   = http
        @out    = out
      end

      # A valid access token, refreshing it if needed.
      def access_token
        token = load_token
        raise Error, "Not logged in to YouTube; run `subetha youtube auth`" unless token

        token = refresh!(token) if Time.now.to_i >= token["expires_at"].to_i - EXPIRY_MARGIN
        token["access_token"]
      end

      def refresh!(token = load_token)
        raise Error, "No refresh token; run `subetha youtube auth`" unless token&.dig("refresh_token")

        res = post_token(grant_type:    "refresh_token",
                         refresh_token: token["refresh_token"])
        unless res.success?
          error = ApiError.from(res, "Refreshing the YouTube login")
          if error.reason == "invalid_grant"
            raise Error, "YouTube login expired or was revoked; run `subetha youtube auth`"
          end
          raise error
        end

        save_token(token.merge(token_fields(res.json)))
      end

      # Runs the browser login and stores the resulting token.
      def login(open_browser: true)
        server   = TCPServer.new("127.0.0.1", 0)
        redirect = "http://127.0.0.1:#{server.addr[1]}/"
        verifier = SecureRandom.urlsafe_base64(64)
        state    = SecureRandom.hex(16)
        url      = authorization_url(redirect, verifier, state)

        @out.puts "Open this URL to log in to YouTube:\n\n  #{url}\n\n"
        launch(url) if open_browser

        params = wait_for_redirect(server)
        raise Error, "Login was cancelled: #{params["error"]}" if params["error"]
        raise Error, "Login response did not match this request" unless params["state"] == state

        res = post_token(grant_type:    "authorization_code",
                         code:          params["code"],
                         redirect_uri:  redirect,
                         code_verifier: verifier)
        raise ApiError.from(res, "Exchanging the YouTube login code") unless res.success?

        save_token(token_fields(res.json))
      ensure
        server&.close
      end

      def authorization_url(redirect, verifier, state)
        challenge = [Digest::SHA256.digest(verifier)].pack("m0").tr("+/", "-_").delete("=")
        query = URI.encode_www_form(
          client_id:             secrets["client_id"],
          redirect_uri:          redirect,
          response_type:         "code",
          scope:                 SCOPES.join(" "),
          # offline + consent makes Google issue a refresh token every time.
          access_type:           "offline",
          prompt:                "consent",
          code_challenge:        challenge,
          code_challenge_method: "S256",
          state:                 state
        )
        "#{secrets["auth_uri"] || AUTH_URI}?#{query}"
      end

      def load_token
        path = @config.token_path
        File.exist?(path) ? JSON.parse(File.read(path)) : nil
      rescue JSON::ParserError
        nil
      end

      private

      def secrets
        @secrets ||= begin
          path = @config.client_secrets
          unless File.exist?(path)
            raise Error, "YouTube client secrets not found at #{path}. Download the OAuth " \
                         "client JSON (Desktop app) from Google Cloud Console and save it there, " \
                         "or set youtube.client_secrets in .subetha.yml"
          end
          data = JSON.parse(File.read(path))
          data["installed"] || data["web"] || data
        end
      end

      def post_token(**params)
        body = URI.encode_www_form(client_id:     secrets["client_id"],
                                   client_secret: secrets["client_secret"],
                                   **params)
        @http.request(:post, secrets["token_uri"] || TOKEN_URI,
                      headers: { "Content-Type" => "application/x-www-form-urlencoded" },
                      body:    body)
      end

      def token_fields(data)
        fields = {
          "access_token" => data["access_token"],
          "expires_at"   => Time.now.to_i + data["expires_in"].to_i,
          "scope"        => data["scope"],
          "token_type"   => data["token_type"]
        }
        # A refresh grant usually omits the refresh token; keep the old one.
        fields["refresh_token"] = data["refresh_token"] if data["refresh_token"]
        fields.compact
      end

      def save_token(token)
        path = @config.token_path
        FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
        File.write(path, JSON.pretty_generate(token))
        File.chmod(0o600, path)
        token
      end

      def launch(url)
        cmd = RUBY_PLATFORM.include?("darwin") ? "open" : "xdg-open"
        system(cmd, url, out: File::NULL, err: File::NULL)
      end

      # Serves requests until one carries the OAuth result (browsers also ask
      # for /favicon.ico and the like).
      def wait_for_redirect(server)
        deadline = Time.now + LOGIN_TIMEOUT
        loop do
          remaining = deadline - Time.now
          raise Error, "Timed out waiting for the YouTube login" if remaining <= 0
          next unless IO.select([server], nil, nil, remaining)

          client = server.accept
          begin
            target = client.gets.to_s.split[1].to_s
            nil until client.gets.to_s.strip.empty?
            params = URI.decode_www_form(URI.parse(target).query.to_s).to_h
            if params.key?("code") || params.key?("error")
              respond(client, 200, "Logged in. You can close this tab and return to the terminal.")
              return params
            end
            respond(client, 404, "Not found")
          ensure
            client.close
          end
        end
      end

      def respond(client, status, text)
        client.write("HTTP/1.1 #{status} #{status == 200 ? "OK" : "Not Found"}\r\n" \
                     "Content-Type: text/plain; charset=utf-8\r\n" \
                     "Content-Length: #{text.bytesize}\r\nConnection: close\r\n\r\n#{text}")
      end
    end
  end
end
