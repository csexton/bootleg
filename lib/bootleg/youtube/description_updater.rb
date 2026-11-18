module Bootleg
  module Youtube
    # Makes uploaded videos' descriptions match their schedule rows. Only the
    # description changes; title, tags, category and schedule are left alone.
    class DescriptionUpdater
      # Snippet fields videos.update would otherwise clear.
      KEEP = %w[title categoryId tags defaultLanguage defaultAudioLanguage].freeze

      def initialize(schedule:, state:, client:, dry_run: false, out: $stdout)
        @schedule = schedule
        @state    = state
        @client   = client
        @dry_run  = dry_run
        @out      = out
      end

      # Returns the number of videos changed (or that would be).
      def run
        wanted = @schedule.entries.filter_map do |entry|
          id = @state.video_id(entry.video_filename)
          @out.puts "-  #{entry.video_filename}: not uploaded, skipping" unless id
          [id, entry] if id
        end
        return 0 if wanted.empty?

        current = @client.list_videos(wanted.map(&:first)).to_h { |v| [v["id"], v["snippet"]] }
        wanted.count { |id, entry| sync(id, entry, current[id]) }
      end

      private

      def sync(id, entry, snippet)
        want = entry.description.to_s.strip
        if snippet.nil?
          @out.puts "!  #{id} #{entry.title}: not found on YouTube"
          return false
        end
        if snippet["description"].to_s.strip == want
          @out.puts "=  #{id} #{entry.title}: already up to date"
          return false
        end
        if @dry_run
          @out.puts "~  #{id} #{entry.title}: would set description ending ...#{want[-70..] || want}"
          return true
        end

        body = { id: id, snippet: snippet.slice(*KEEP).merge("description" => want) }
        @client.update_video(body)
        @out.puts "✓  #{id} #{entry.title}: description updated"
        true
      end
    end
  end
end
