require "colorize"

module Subetha
  # Entry point for the `subetha` executable. Routes `subetha <platform> ...`
  # to that platform's CLI; each platform CLI returns an exit status.
  module CLI
    PLATFORMS = {
      "tiktok" => -> { Tiktok::CLI }
    }.freeze

    USAGE = <<~USAGE.freeze
      Usage: subetha PLATFORM COMMAND [options]

      Platforms:
          tiktok      download    Download videos and photo posts
                      list        List the video URLs on a profile

      Options:
          -v, --version           Print the version
          -h, --help              Show this help message

      Run `subetha PLATFORM --help` for a platform's commands and options.
    USAGE

    def self.start(argv)
      argv = argv.dup
      platform = argv.shift

      case platform
      when nil, "-h", "--help", "help"
        puts USAGE
        platform.nil? ? 1 : 0
      when "-v", "--version", "version"
        puts VERSION
        0
      else
        cli = PLATFORMS[platform]
        unless cli
          $stderr.puts "Unknown platform: #{platform}".red
          $stderr.puts USAGE
          return 1
        end
        cli.call.start(argv)
      end
    end
  end
end
