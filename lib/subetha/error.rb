module Subetha
  # Base class for errors subetha raises on purpose, so the CLI can report
  # them as one-line messages rather than stack traces.
  class Error < StandardError; end
end
