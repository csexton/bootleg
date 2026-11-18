require "yaml"

module Bootleg
  # Directory for bootleg's own state (credentials, tokens), following XDG.
  def self.config_dir
    base = ENV["XDG_CONFIG_HOME"].to_s
    base = File.expand_path("~/.config") if base.empty?
    File.join(base, "bootleg")
  end

  # Reads the user's .bootleg.yml. Each platform keeps its settings under its
  # own top-level key (e.g. "tiktok:"), so one file can configure them all.
  # The file in the current directory takes precedence over the one in $HOME.
  module ConfigFile
    FILENAME = ".bootleg.yml".freeze

    def self.candidates
      [File.join(Dir.pwd, FILENAME), File.expand_path("~/#{FILENAME}")]
    end

    def self.path
      candidates.find { |f| File.exist?(f) }
    end

    def self.load
      file = path
      data = file ? YAML.safe_load_file(file) : nil
      data.is_a?(Hash) ? data : {}
    end

    # The settings hash for one platform, or {} when the file has none.
    def self.section(name)
      value = load[name.to_s]
      value.is_a?(Hash) ? value : {}
    end
  end
end
