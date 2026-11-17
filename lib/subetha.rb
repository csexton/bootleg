require_relative "subetha/version"
require_relative "subetha/tiktok"
require_relative "subetha/cli"

# Download, archive, and publish videos across social platforms. Each platform
# lives in its own namespace (Subetha::Tiktok, ...) and exposes its commands
# through the top-level CLI as `subetha <platform> <command>`.
module Subetha
end
