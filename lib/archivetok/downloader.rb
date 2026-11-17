require "net/http"
require "uri"
require "fileutils"
require "colorize"
require_relative "ssl_helper"

module Archivetok
  class Downloader
    include SslHelper
    DESKTOP_UA   = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 " \
                   "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    MAX_REDIRECTS = 5

    def initialize(config)
      @output_dir        = config.output_dir
      @json_sidecar      = config.json_sidecar
      @filename_username = config.filename_username
      @filename_date     = config.filename_date
      @filename_id       = config.filename_id
      @filename_slug     = config.filename_slug
      FileUtils.mkdir_p(@output_dir)
    end

    def save_video(data, source_url)
      base = unique_base(
        stem_path(data[:author_id], data[:create_time], data[:video_id],
                  description: data[:description]),
        data[:video_id]
      )
      path = "#{base}.mp4"
      puts "  Downloading video...".white
      write_binary(data[:video_url], path, source_url, cookies: data[:cookies])
      puts "  Saved: #{File.basename(path)}".green
      write_sidecar(base, data, source_url)
    end

    def save_images(data, image_urls, source_url)
      base = unique_base(
        stem_path(data[:author_id], data[:create_time], data[:media_id],
                  description: data[:description]),
        data[:media_id]
      )
      image_urls.each_with_index do |img_url, i|
        path = "#{base}-#{(i + 1).to_s.rjust(2, '0')}.jpg"
        puts "  Downloading image #{i + 1}/#{image_urls.size}...".white
        write_binary(img_url, path, source_url, cookies: data[:cookies])
        puts "  Saved: #{File.basename(path)}".green
      end
      write_sidecar(base, data, source_url)
    end

    private

    # Full path for a post's files, minus the extension.
    def stem_path(author_id, timestamp, media_id, description: nil)
      parts = []
      parts << author_id              if @filename_username
      parts << format_date(timestamp) if @filename_date
      parts << slugify(description)   if @filename_slug
      parts << media_id               if @filename_id
      parts.compact!
      parts << media_id if parts.empty?  # always need something
      File.join(@output_dir, parts.join("-"))
    end

    # Two posts whose captions open alike slugify to the same name. Append the
    # media id rather than clobber a different post's download.
    def unique_base(base, media_id)
      return base if @filename_id || media_id.to_s.empty?

      owner = base_owner(base)
      return base if owner.nil? || owner == media_id.to_s

      note = owner == :unknown ? "another post" : owner
      puts "  Name taken by #{note}; appending ID".yellow
      "#{base}-#{media_id}"
    end

    # The media id already using this base name, :unknown if files are there but
    # can't be attributed, nil if the name is free.
    def base_owner(base)
      owner = sidecar_owner(base)
      return owner if owner
      return :unknown if File.exist?("#{base}.mp4") || File.exist?("#{base}-01.jpg")

      nil
    end

    def sidecar_owner(base)
      if File.exist?("#{base}.json")
        require "json"
        id = begin
          JSON.parse(File.read("#{base}.json"))["video_id"]
        rescue JSON::ParserError
          nil
        end
        id.to_s.empty? ? :unknown : id.to_s
      elsif File.exist?("#{base}.txt")
        m = File.read("#{base}.txt").match(/^Video ID:\s*(\S+)/)
        m ? m[1] : :unknown
      end
    end

    def slugify(text, max_words: 8, min_sentence_words: 5)
      return nil if text.nil? || text.strip.empty?

      # Try first sentence — use it if it lands in the sweet spot (5+ words)
      if (m = text.match(/\A(.+?)[.!?](?:\s|$)/))
        sentence_words = m[1].downcase.gsub(/[''']/, "").gsub(/[^a-z0-9]+/, " ").strip.split
        if sentence_words.length >= min_sentence_words
          return sentence_words.first(max_words).join("-")
        end
      end

      # Fall back to first max_words words of full text
      words = text.downcase.gsub(/[''']/, "").gsub(/[^a-z0-9]+/, " ").strip.split
      slug  = words.first(max_words).join("-")
      slug.empty? ? nil : slug
    end

    def format_date(unix_ts)
      Time.at(unix_ts.to_i).strftime("%Y-%m-%d")
    end

    # Stream to a .part file and rename once complete, so an interrupted
    # download never leaves a truncated file that looks like a finished one.
    def write_binary(url, path, referer, cookies: nil)
      tmp = "#{path}.part"
      stream_to(url, tmp, referer, cookies: cookies)
      File.rename(tmp, path)
    rescue StandardError, Interrupt
      File.delete(tmp) if tmp && File.exist?(tmp)
      raise
    end

    def stream_to(url, path, referer, cookies: nil, redirect_count: 0)
      raise "Too many redirects" if redirect_count > MAX_REDIRECTS

      uri = URI.parse(url)
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = DESKTOP_UA
      req["Referer"]    = referer
      req["Cookie"]     = cookies if cookies && !cookies.empty?

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                      cert_store: ssl_store,
                      open_timeout: 15, read_timeout: 120) do |http|
        http.request(req) do |response|
          case response
          when Net::HTTPSuccess
            File.open(path, "wb") { |f| response.read_body { |chunk| f.write(chunk) } }
          when Net::HTTPRedirection
            stream_to(redirect_target(uri, response), path, referer,
                      cookies: cookies, redirect_count: redirect_count + 1)
          else
            raise "Download HTTP #{response.code} for #{url}"
          end
        end
      end
    end

    # Location may be relative; resolve it against the URL we requested.
    def redirect_target(uri, response)
      location = response["location"]
      raise "Redirect with no Location header" if location.nil? || location.empty?

      uri.merge(location).to_s
    end

    def write_sidecar(base, data, source_url)
      if @json_sidecar
        write_json_sidecar("#{base}.json", data, source_url)
      else
        write_txt_sidecar("#{base}.txt", data, source_url)
      end
    end

    def write_txt_sidecar(path, data, source_url)
      date = Time.at(data[:create_time].to_i).strftime("%Y-%m-%d")
      id   = data[:video_id] || data[:media_id]
      text = <<~TXT
        Title:       #{data[:description]}
        Author:      #{data[:author_name]} (@#{data[:author_id]})
        Date:        #{date}
        Video ID:    #{id}
        Source URL:  #{source_url}
      TXT
      if (audio = data[:audio])
        text += "Audio:       #{Audio.label(audio)}\n"
        text += "Audio URL:   #{audio[:url]}\n" if audio[:url]
      end
      File.write(path, text)
      puts "  Saved: #{File.basename(path)}".green
    end

    def write_json_sidecar(path, data, source_url)
      require "json"
      date = Time.at(data[:create_time].to_i).strftime("%Y-%m-%d")
      id   = data[:video_id] || data[:media_id]
      payload = {
        title:      data[:description],
        author:     { name: data[:author_name], username: data[:author_id] },
        date:       date,
        video_id:   id,
        source_url: source_url
      }
      payload[:audio] = data[:audio] if data[:audio]
      File.write(path, JSON.pretty_generate(payload))
      puts "  Saved: #{File.basename(path)}".green
    end
  end
end
