require "date"
require "fileutils"

module Bootleg
  module Youtube
    # Builds a batch directory (schedule.csv + videos/) from downloaded TikTok
    # posts, one per day.
    #
    # A picks file lists the posts in publish order, one per line:
    #
    #   ~/tiktok/someuser-2026-11-07-inlay-dovetails-pt-1-this-is-the-part | Inlay Dovetails Pt. 1
    #
    # i.e. the post's path (any extension, or none) and the YouTube title.
    # Blank lines and lines starting with # are ignored.
    class ScheduleBuilder
      Pick = Struct.new(:base, :title)

      def self.parse_picks(text)
        text.each_line.filter_map do |line|
          next if line.strip.empty? || line.lstrip.start_with?("#")

          path, sep, title = line.partition("|")
          raise Error, "Pick line has no '| Title': #{line.strip}" if sep.empty? || title.strip.empty?

          Pick.new(File.expand_path(path.strip), title.strip)
        end
      end

      def initialize(config, out: $stdout)
        @config = config
        @out    = out
      end

      def build(picks, dir:, start:, publish_time: @config.publish_time, force: false)
        schedule_path = File.join(dir, Schedule::FILENAME)
        if File.exist?(schedule_path) && !force
          raise Error, "#{schedule_path} already exists; use --force to replace it, " \
                       "or build into a new directory"
        end

        start     = Date.iso8601(start.to_s)
        video_dir = File.join(dir, "videos")
        sources   = picks.map { |pick| [pick, Tiktok::Sidecar.find(pick.base)] }
        sources.each do |_, sidecar|
          raise Error, "Video not found: #{sidecar.video_path}" unless File.exist?(sidecar.video_path)
        end

        FileUtils.mkdir_p(video_dir)
        entries = sources.each_with_index.map do |(pick, sidecar), i|
          entry = entry_for(pick, sidecar, i, start + i, publish_time)
          FileUtils.cp(sidecar.video_path, File.join(video_dir, entry.video_filename), preserve: true)
          @out.puts "#{entry.publish_date} #{entry.publish_time}  #{entry.video_filename} | #{entry.title}"
          entry
        end

        Schedule.write(schedule_path, entries)
      rescue Date::Error
        raise Error, "Start date #{start.inspect} is not YYYY-MM-DD"
      end

      private

      def entry_for(pick, sidecar, index, date, publish_time)
        caption = sidecar.title
        Schedule::Entry.new(
          video_filename: format("%02d-%s.mp4", index + 1, slug(sidecar.base)),
          title:          pick.title,
          description:    AudioCredit.append(caption, AudioCredit.from_label(sidecar.audio_label)),
          tags:           tags_for(caption).join(","),
          publish_date:   date.iso8601,
          publish_time:   publish_time,
          privacy_status: "private",
          category_id:    @config.category_id,
          made_for_kids:  "false"
        )
      end

      # The caption's hashtags (or the configured defaults), plus "shorts".
      def tags_for(caption)
        tags = caption.scan(/#(\w+)/).flatten.uniq
        tags = @config.default_tags.dup if tags.empty?
        tags << "shorts" unless tags.include?("shorts")
        tags
      end

      # "user-2026-11-07-some-slug" -> "some-slug"
      def slug(base)
        File.basename(base).sub(/\A.*?-\d{4}-\d{2}-\d{2}-/, "")
      end
    end
  end
end
