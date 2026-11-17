require "csv"
require "tzinfo"

module Subetha
  module Youtube
    # A CSV of videos to upload, one row each. The columns match the original
    # youtube-shorts-scheduler, so its schedule files load unchanged.
    class Schedule
      COLUMNS = %w[video_filename title description tags publish_date publish_time
                   privacy_status category_id made_for_kids].freeze
      FILENAME = "schedule.csv".freeze

      Entry = Struct.new(*COLUMNS.map(&:to_sym), keyword_init: true) do
        def tag_list
          tags.to_s.split(",").map(&:strip).reject(&:empty?)
        end

        def made_for_kids?
          made_for_kids.to_s.strip.casecmp?("true")
        end

        def privacy
          value = privacy_status.to_s.strip.downcase
          value.empty? ? "private" : value
        end

        def scheduled?
          !publish_date.to_s.strip.empty?
        end

        # RFC 3339 publish time in `timezone`, with that date's real offset.
        def publish_at(timezone)
          return nil unless scheduled?

          date  = Date.iso8601(publish_date.strip)
          parts = publish_time.to_s.strip.split(":").map(&:to_i)
          raise Error, "#{video_filename}: publish_time is missing" if parts.empty?

          # dst: true picks the first of two repeated fall-back hours, as
          # Python's zoneinfo did.
          TZInfo::Timezone.get(timezone)
                          .local_time(date.year, date.month, date.day, *(parts + [0, 0]).first(3), 0, true)
                          .iso8601
        rescue Date::Error
          raise Error, "#{video_filename}: publish_date #{publish_date.inspect} is not YYYY-MM-DD"
        rescue TZInfo::PeriodNotFound
          raise Error, "#{video_filename}: #{publish_date} #{publish_time} does not exist in " \
                       "#{timezone} (DST change)"
        end

        # The videos.insert body.
        def metadata(timezone)
          if scheduled? && privacy != "private"
            raise Error, "#{video_filename}: scheduled videos must be private until they " \
                         "publish (privacy_status is #{privacy})"
          end

          status = { privacyStatus: privacy, selfDeclaredMadeForKids: made_for_kids? }
          status[:publishAt] = publish_at(timezone) if scheduled?
          category = category_id.to_s.strip
          {
            snippet: { title:       title.to_s.strip,
                       description: description.to_s.strip,
                       tags:        tag_list,
                       categoryId:  category.empty? ? "22" : category },
            status:  status
          }
        end
      end

      attr_reader :path, :entries

      # `path` may be the CSV or the directory holding schedule.csv.
      def self.resolve(path)
        path = File.expand_path(path || FILENAME)
        File.directory?(path) ? File.join(path, FILENAME) : path
      end

      def self.load(path)
        path = resolve(path)
        raise Error, "Schedule not found: #{path}" unless File.exist?(path)

        table = CSV.read(path, headers: true, encoding: "bom|utf-8")
        missing = %w[video_filename title] - table.headers
        raise Error, "#{path} is missing column(s): #{missing.join(", ")}" if missing.any?

        entries = table.map do |row|
          Entry.new(**COLUMNS.to_h { |c| [c.to_sym, row[c].to_s] })
        end
        new(path, entries)
      end

      def self.write(path, entries)
        CSV.open(path, "w") do |csv|
          csv << COLUMNS
          entries.each { |e| csv << COLUMNS.map { |c| e[c.to_sym] } }
        end
        new(path, entries)
      end

      def initialize(path, entries)
        @path    = path
        @entries = entries
      end

      def dir
        File.dirname(path)
      end

      # Videos live in videos/ beside the schedule unless told otherwise;
      # absolute filenames are used as they are.
      def video_path(entry, video_dir = nil)
        File.expand_path(entry.video_filename, video_dir || File.join(dir, "videos"))
      end
    end
  end
end
