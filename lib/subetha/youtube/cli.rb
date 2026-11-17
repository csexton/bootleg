require "optparse"
require "colorize"

module Subetha
  module Youtube
    # `subetha youtube auth|schedule|upload|update-descriptions|shorts ...`
    class CLI
      USAGE = <<~USAGE.freeze
        Usage: subetha youtube COMMAND [options]

        Commands:
            auth                        Log in to YouTube (opens a browser)
            schedule PICKS --start DATE Build a batch (schedule.csv + videos/) from
                                        downloaded TikToks, one per day
            upload [SCHEDULE]           Upload and schedule every video not yet uploaded
            update-descriptions [SCHEDULE]
                                        Push edited descriptions to uploaded videos
            shorts [@HANDLE]            List the titles of a channel's newest Shorts

        SCHEDULE is a schedule.csv or the directory holding one (default: .).

        Options:
            schedule:
                --start DATE            First publish date, YYYY-MM-DD (required)
                --time HH:MM            Publish time each day (default: 19:00)
                --dir DIR               Batch directory to create (default: .)
                --force                 Replace an existing schedule.csv
            upload:
                --dry-run               Check the schedule without uploading
                --delay SECONDS         Pause between uploads (default: 45)
                --video-dir DIR         Where the videos are (default: SCHEDULE's videos/)
            update-descriptions:
                --dry-run               Show what would change
            auth:
                --no-browser            Print the login URL without opening it

            -h, --help                  Show this help message

        Config file:
            ./.subetha.yml or ~/.subetha.yml, under a "youtube:" key.
            Supported keys: client_secrets, token_path, timezone, delay, publish_time,
                            category_id, default_tags, handle

        Examples:
            subetha youtube auth
            subetha youtube schedule picks.txt --start 2026-12-01 --dir batches/2026-12
            subetha youtube upload batches/2026-12 --dry-run
            subetha youtube upload batches/2026-12
            subetha youtube shorts @someuser
      USAGE

      COMMANDS = %w[auth schedule upload update-descriptions shorts].freeze

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
          $stderr.puts "Unknown youtube command: #{command}".red
          $stderr.puts USAGE
          return 1
        end

        options = parse_options(argv)
        return 0 if options.nil?

        send(command.tr("-", "_"), argv, options)
      rescue OptionParser::ParseError => e
        $stderr.puts "#{e.message}\n\n#{USAGE}"
        1
      rescue Error => e
        $stderr.puts "Error: #{e.message}".red
        1
      rescue Interrupt
        $stderr.puts "\nInterrupted.".yellow
        1
      end

      private

      def auth(_args, options)
        config = Config.load
        Auth.new(config).login(open_browser: options.fetch(:browser, true))
        $stderr.puts "Logged in. Token saved to #{config.token_path}".green
        0
      end

      def schedule(args, options)
        picks_file = args.first or raise Error, "Give a picks file: subetha youtube schedule PICKS --start DATE"
        raise Error, "--start DATE is required" unless options[:start]
        raise Error, "Picks file not found: #{picks_file}" unless File.exist?(picks_file)

        config = Config.load
        picks  = ScheduleBuilder.parse_picks(File.read(picks_file))
        raise Error, "#{picks_file} has no picks" if picks.empty?

        dir      = File.expand_path(options[:dir] || ".")
        schedule = ScheduleBuilder.new(config).build(
          picks, dir: dir, start: options[:start],
                 publish_time: options[:time] || config.publish_time, force: options[:force]
        )
        $stderr.puts "\nWrote #{schedule.path} (#{picks.size} video(s)). Check it, then run:".green
        $stderr.puts "  subetha youtube upload #{relative(schedule.dir)} --dry-run"
        0
      end

      def upload(args, options)
        config   = Config.load(options.slice(:delay))
        schedule = Schedule.load(args.first)
        client   = Client.new(Auth.new(config)) unless options[:dry_run]
        summary  = BatchUploader.new(
          schedule: schedule, state: UploadState.for(schedule), config: config, client: client,
          video_dir: options[:video_dir] && File.expand_path(options[:video_dir]),
          dry_run: options[:dry_run]
        ).run
        summary.ok? ? 0 : 1
      end

      def update_descriptions(args, options)
        config   = Config.load
        schedule = Schedule.load(args.first)
        DescriptionUpdater.new(schedule: schedule, state: UploadState.for(schedule),
                               client: Client.new(Auth.new(config)),
                               dry_run: options[:dry_run]).run
        0
      end

      def shorts(args, _options)
        handle = args.first || Config.load.handle
        raise Error, "Give a channel handle, or set youtube.handle in .subetha.yml" unless handle

        titles = ShortsLister.titles(handle)
        $stderr.puts "No Shorts found (the page layout may have changed)".yellow if titles.empty?
        titles.each { |t| $stdout.puts t }
        titles.empty? ? 1 : 0
      end

      # Returns nil when --help was handled.
      def parse_options(argv)
        options = {}
        help    = false
        OptionParser.new do |opts|
          opts.on("--start DATE")        { |v| options[:start] = v }
          opts.on("--time HH:MM")        { |v| options[:time] = v }
          opts.on("--dir DIR")           { |v| options[:dir] = v }
          opts.on("--force")             { options[:force] = true }
          opts.on("--dry-run")           { options[:dry_run] = true }
          opts.on("--delay N", Integer)  { |v| options[:delay] = v }
          opts.on("--video-dir DIR")     { |v| options[:video_dir] = v }
          opts.on("--[no-]browser")      { |v| options[:browser] = v }
          opts.on("-h", "--help")        { help = true }
        end.parse!(argv)
        return options unless help

        puts USAGE
        nil
      end

      def relative(path)
        path.start_with?("#{Dir.pwd}/") ? path.delete_prefix("#{Dir.pwd}/") : path
      end
    end
  end
end
