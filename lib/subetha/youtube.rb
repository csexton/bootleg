require_relative "error"
require_relative "config_file"
require_relative "youtube/http"
require_relative "youtube/config"
require_relative "youtube/auth"
require_relative "youtube/client"
require_relative "youtube/schedule"
require_relative "youtube/upload_state"
require_relative "youtube/audio_credit"
require_relative "youtube/schedule_builder"
require_relative "youtube/batch_uploader"
require_relative "youtube/description_updater"
require_relative "youtube/shorts_lister"
require_relative "youtube/cli"

module Subetha
  # YouTube as a destination: log in, build a schedule from downloaded posts,
  # upload and schedule it, and keep uploaded descriptions in sync.
  module Youtube
  end
end
