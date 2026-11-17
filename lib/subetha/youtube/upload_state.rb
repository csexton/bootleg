require "json"
require "time"

module Subetha
  module Youtube
    # Which schedule rows have been uploaded, and as which video, kept in
    # uploads.json beside the schedule. Re-running a batch skips these, and
    # update-descriptions uses the ids.
    class UploadState
      FILENAME = "uploads.json".freeze

      attr_reader :path

      def self.for(schedule)
        new(File.join(schedule.dir, FILENAME))
      end

      def initialize(path)
        @path    = path
        @uploads = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      end

      def uploaded?(filename)
        @uploads.key?(filename)
      end

      def video_id(filename)
        @uploads.dig(filename, "video_id")
      end

      def size
        @uploads.size
      end

      def record(filename, video_id:, title: nil, publish_at: nil)
        @uploads[filename] = {
          "video_id"    => video_id,
          "title"       => title,
          "publish_at"  => publish_at,
          "uploaded_at" => Time.now.utc.iso8601
        }.compact
        save
      end

      private

      # Write then rename, so a crash never leaves half a file.
      def save
        tmp = "#{path}.tmp"
        File.write(tmp, JSON.pretty_generate(@uploads))
        File.rename(tmp, path)
      end
    end
  end
end
