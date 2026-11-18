module Bootleg
  module Youtube
    Config = Struct.new(:client_secrets, :token_path, :timezone, :delay, :publish_time,
                        :category_id, :default_tags, :handle, keyword_init: true) do
      def self.load(cli_options = {})
        yaml = ConfigFile.section("youtube")
        get  = ->(key, default) { cli_options.fetch(key) { yaml.fetch(key.to_s, default) } }
        dir  = File.join(Bootleg.config_dir, "youtube")

        new(
          client_secrets: File.expand_path(get.(:client_secrets, File.join(dir, "client_secrets.json"))),
          token_path:     File.expand_path(get.(:token_path, File.join(dir, "token.json"))),
          timezone:       get.(:timezone, nil) || system_timezone,
          delay:          get.(:delay, 45).to_i,
          publish_time:   get.(:publish_time, "19:00").to_s,
          # 22 is People & Blogs, YouTube's own default.
          category_id:    get.(:category_id, "22").to_s,
          default_tags:   Array(get.(:default_tags, [])).map(&:to_s),
          handle:         get.(:handle, nil)
        )
      end

      # The IANA name of the machine's zone, from $TZ or the /etc/localtime link.
      def self.system_timezone
        return ENV["TZ"] unless ENV["TZ"].to_s.empty?

        File.readlink("/etc/localtime")[%r{zoneinfo/(.+)\z}, 1] || "UTC"
      rescue SystemCallError
        "UTC"
      end
    end
  end
end
