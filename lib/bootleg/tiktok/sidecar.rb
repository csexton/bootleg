require "json"

module Bootleg
  module Tiktok
    # Reads back the metadata sidecar the Downloader writes next to a post,
    # in either its .txt or .json form.
    class Sidecar
      TXT_LABELS = {
        "Title"      => :title,
        "Author"     => :author,
        "Date"       => :date,
        "Video ID"   => :video_id,
        "Source URL" => :source_url,
        "Audio"      => :audio_label,
        "Audio URL"  => :audio_url
      }.freeze
      TXT_LINE = /\A(#{TXT_LABELS.keys.map { |k| Regexp.escape(k) }.join("|")}):\s?(.*)\z/

      attr_reader :path, :title, :author, :date, :video_id, :source_url, :audio_label, :audio_url

      # `base` is the post's path with or without an extension; the .txt
      # sidecar is preferred when both exist.
      def self.find(base)
        base = base.sub(/\.(txt|json|mp4)\z/, "")
        path = ["#{base}.txt", "#{base}.json"].find { |p| File.exist?(p) }
        raise Error, "No sidecar found for #{base}" unless path

        new(path)
      end

      def initialize(path)
        @path = path
        path.end_with?(".json") ? parse_json(File.read(path)) : parse_txt(File.read(path))
      end

      # The post's path without an extension, shared by its media files.
      def base
        path.sub(/\.(txt|json)\z/, "")
      end

      def video_path
        "#{base}.mp4"
      end

      private

      # Captions can span lines, so any line that doesn't start with a known
      # label continues the caption.
      def parse_txt(text)
        fields  = {}
        current = nil
        text.each_line(chomp: true) do |line|
          if (m = line.match(TXT_LINE))
            current = TXT_LABELS[m[1]]
            fields[current] = m[2].strip
          elsif current == :title
            fields[:title] << "\n" << line
          end
        end
        fields[:title] = fields[:title]&.strip

        assign(**fields)
      end

      def parse_json(text)
        data   = JSON.parse(text)
        author = data["author"] || {}
        audio  = data["audio"]
        label  = (Audio.label(audio.transform_keys(&:to_sym)) if audio.is_a?(Hash))
        assign(title:       data["title"].to_s,
               author:      "#{author["name"]} (@#{author["username"]})",
               date:        data["date"].to_s,
               video_id:    data["video_id"].to_s,
               source_url:  data["source_url"].to_s,
               audio_label: label,
               audio_url:   (audio["url"] if audio.is_a?(Hash)))
      end

      def assign(title: "", author: nil, date: nil, video_id: nil, source_url: nil,
                 audio_label: nil, audio_url: nil)
        @title, @author, @date, @video_id = title.to_s, author, date, video_id
        @source_url, @audio_label, @audio_url = source_url, audio_label, audio_url
      end
    end
  end
end
