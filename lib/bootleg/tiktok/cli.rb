require "optparse"
require "colorize"

module Bootleg
  module Tiktok
    # `bootleg tiktok download|list ...`
    class CLI
      USAGE = <<~USAGE.freeze
        Usage: bootleg tiktok COMMAND [options] URL [URL...]

        Commands:
            download URL [URL...]   Download videos and photo posts
            list PROFILE_URL...     Print the video URLs on a profile to stdout
            index [DIR]             Print "date | id | caption" for each downloaded post,
                                    newest first (default: the output directory)

        Download options:
            --output-dir DIR        Directory to save files (default: current directory)
            --json                  Save sidecar as JSON instead of plain text
            --[no-]username         Include username in filename (default: on)
            --[no-]date             Include date in filename (default: on)
            --[no-]id               Include video ID in filename (default: off)
            --[no-]slug             Include description slug in filename (default: on)

        List options:
            --pages N               Number of pages to fetch (default: 1)

            -h, --help              Show this help message

        Config file:
            ./.bootleg.yml or ~/.bootleg.yml, under a "tiktok:" key.
            Supported keys: output_dir, json_sidecar, pages,
                            filename_username, filename_date, filename_id, filename_slug

        Examples:
            bootleg tiktok download https://www.tiktok.com/@user/video/123456
            bootleg tiktok download --output-dir ~/Videos/tiktok https://vm.tiktok.com/abc123/
            bootleg tiktok download --no-username --no-date https://...   # slug only
            bootleg tiktok list --pages 3 https://www.tiktok.com/@user
            bootleg tiktok list https://www.tiktok.com/@user | xargs bootleg tiktok download
      USAGE

      COMMANDS = %w[download list index].freeze

      def self.start(argv)
        new.start(argv)
      end

      def start(argv)
        argv    = argv.dup
        command = argv.shift

        if command.nil? || %w[-h --help help].include?(command)
          puts USAGE
          return command.nil? ? 1 : 0
        end

        unless COMMANDS.include?(command)
          $stderr.puts "Unknown tiktok command: #{command}".red
          $stderr.puts USAGE
          return 1
        end

        options = parse_options(argv)
        return 0 if options.nil?

        config = Config.load(options)
        return index(argv.first || config.output_dir) if command == "index"

        if argv.empty?
          $stderr.puts USAGE
          return 1
        end

        command == "list" ? list(argv, config) : download(argv, config)
      rescue OptionParser::ParseError => e
        $stderr.puts "#{e.message}\n\n#{USAGE}"
        1
      end

      private

      # Returns nil when --help was handled.
      def parse_options(argv)
        options = {}
        help    = false
        OptionParser.new do |opts|
          opts.on("--output-dir DIR")  { |d| options[:output_dir] = d }
          opts.on("--json")            { options[:json_sidecar] = true }
          opts.on("--pages N", Integer) { |n| options[:pages] = n }
          opts.on("--[no-]username")   { |v| options[:filename_username] = v }
          opts.on("--[no-]date")       { |v| options[:filename_date]     = v }
          opts.on("--[no-]id")         { |v| options[:filename_id]       = v }
          opts.on("--[no-]slug")       { |v| options[:filename_slug]     = v }
          opts.on("-h", "--help")      { help = true }
        end.parse!(argv)
        return options unless help

        puts USAGE
        nil
      end

      def download(urls, config)
        $stderr.puts "Output directory: #{config.output_dir}".white
        processor = Processor.new(config)

        each_url(urls) do |url|
          if UrlValidator.profile?(url)
            raise "#{url} is a profile; use `bootleg tiktok list` to get its video URLs"
          end

          processor.process(url)
        end
      end

      def list(urls, config)
        each_url(urls) do |url|
          raise "#{url} is not a profile URL" unless UrlValidator.profile?(url)

          $stderr.puts "\n=> Listing videos for: #{url}".cyan
          video_urls = ProfileExtractor.extract(url, pages: config.pages)
          raise "No videos found" if video_urls.empty?

          $stderr.puts "  Total: #{video_urls.size} video(s)".green
          video_urls.each { |u| $stdout.puts u }
        end
      end

      def index(dir)
        unless File.directory?(dir)
          $stderr.puts "Not a directory: #{dir}".red
          return 1
        end

        # A .json sidecar only counts when there is no .txt for the same post.
        paths = Dir[File.join(dir, "*.{txt,json}")].sort
        paths = paths.reject { |p| p.end_with?(".json") && paths.include?(p.sub(/\.json\z/, ".txt")) }
        rows  = paths.filter_map do |path|
          sidecar = Sidecar.new(path)
          next if sidecar.video_id.to_s.empty?

          [sidecar.date.to_s, sidecar.video_id, sidecar.title.tr("\n", " ")[0, 80]]
        rescue JSON::ParserError
          nil
        end
        rows.sort.reverse_each { |row| $stdout.puts row.join(" | ") }
        0
      end

      # Runs the block for each URL, pausing between requests, and collects
      # failures so one bad URL doesn't stop the batch. Returns an exit status.
      def each_url(urls)
        errors = []

        urls.each_with_index do |url, i|
          pause if i > 0

          unless UrlValidator.valid?(url)
            $stderr.puts "Skipping invalid URL: #{url}".red
            errors << url
            next
          end

          begin
            yield url
          rescue Interrupt
            $stderr.puts "\nInterrupted.".yellow
            return 1
          rescue StandardError => e
            $stderr.puts "  Error: #{e.message}".red
            errors << url
          end
        end

        report(errors)
      end

      def pause
        sleep 2
      end

      def report(errors)
        $stderr.puts ""
        if errors.any?
          $stderr.puts "Completed with #{errors.size} error(s):".yellow
          errors.each { |u| $stderr.puts "  - #{u}".red }
          1
        else
          $stderr.puts "Done.".green
          0
        end
      end
    end
  end
end
