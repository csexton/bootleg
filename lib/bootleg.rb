require_relative "bootleg/version"
require_relative "bootleg/error"
require_relative "bootleg/tiktok"
require_relative "bootleg/youtube"
require_relative "bootleg/cli"

# Download, archive, and publish videos across social platforms. Each platform
# lives in its own namespace (Bootleg::Tiktok, Bootleg::Youtube, ...) and
# exposes its commands through the top-level CLI as `bootleg <platform> <command>`.
module Bootleg
end
