require "fileutils"

module Bootleg
  module Youtube
    # Uploads every row of a schedule that isn't in uploads.json yet, waiting
    # between uploads, and records each one as it lands so a failed or
    # quota-limited run can simply be re-run.
    class BatchUploader
      LOG_FILENAME = "upload.log".freeze

      Summary = Struct.new(:uploaded, :skipped, :failed, :stopped, keyword_init: true) do
        def ok?
          failed.zero? && !stopped
        end
      end

      def initialize(schedule:, state:, config:, client: nil, video_dir: nil, dry_run: false,
                     delay: config.delay, out: $stdout, sleeper: ->(s) { sleep s })
        @schedule  = schedule
        @state     = state
        @config    = config
        @client    = client
        @video_dir = video_dir
        @dry_run   = dry_run
        @delay     = delay
        @out       = out
        @sleeper   = sleeper
      end

      def run
        summary = Summary.new(uploaded: 0, skipped: 0, failed: 0, stopped: false)
        entries = @schedule.entries
        mode    = @dry_run ? "DRY RUN, nothing will be uploaded" : "uploading"
        log "Batch #{@schedule.path} (#{mode}): #{entries.size} video(s), " \
            "#{@state.size} already uploaded, times in #{@config.timezone}"

        entries.each_with_index do |entry, i|
          name = entry.video_filename
          @out.puts "\n[#{i + 1}/#{entries.size}] #{name}"

          if @state.uploaded?(name)
            log "SKIPPED (already uploaded as #{@state.video_id(name)}): #{name}"
            summary.skipped += 1
            next
          end

          begin
            upload(entry, pause_first: summary.uploaded.positive? && !@dry_run)
            summary.uploaded += 1
          rescue ApiError => e
            summary.failed += 1
            log "FAILED: #{name}: #{e.message}"
            next unless e.quota?

            log "YouTube's upload quota is used up; stopping. Re-run after it resets " \
                "(midnight Pacific) to upload the rest."
            summary.stopped = true
            break
          rescue Error, SystemCallError => e
            summary.failed += 1
            log "FAILED: #{name}: #{e.message}"
          end
        end

        log "Done: #{summary.uploaded} #{@dry_run ? "would upload" : "uploaded"}, " \
            "#{summary.skipped} skipped, #{summary.failed} failed"
        summary
      end

      private

      def upload(entry, pause_first:)
        path     = @schedule.video_path(entry, @video_dir)
        metadata = entry.metadata(@config.timezone)
        raise Error, "Video file not found: #{path}" unless File.exist?(path)

        publish = metadata[:status][:publishAt] || "not scheduled (#{entry.privacy})"
        @out.puts "  Title:    #{metadata[:snippet][:title]}"
        @out.puts "  Publish:  #{publish}"

        if @dry_run
          log "DRY RUN: would upload #{entry.video_filename}"
          return
        end

        if pause_first && @delay.positive?
          @out.puts "  Waiting #{@delay}s before uploading..."
          @sleeper.call(@delay)
        end

        video = @client.insert_video(path, metadata) do |sent, total|
          @out.print "\r  Progress: #{(sent * 100 / total)}%"
        end
        @out.puts
        @state.record(entry.video_filename, video_id: video["id"],
                                            title:      metadata[:snippet][:title],
                                            publish_at: metadata[:status][:publishAt])
        log "SUCCESS: #{entry.video_filename} -> https://youtu.be/#{video["id"]}"
      end

      # Prints and appends to upload.log beside the schedule.
      def log(message)
        line = "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}"
        @out.puts line
        File.open(File.join(@schedule.dir, LOG_FILENAME), "a") { |f| f.puts line } unless @dry_run
      end
    end
  end
end
