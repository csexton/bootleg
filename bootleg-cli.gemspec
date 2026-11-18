require_relative "lib/bootleg/version"

Gem::Specification.new do |spec|
  spec.name    = "bootleg-cli"
  spec.version = Bootleg::VERSION
  spec.authors = ["Christopher Sexton"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/csexton/bootleg"
  spec.metadata["source_code_uri"] = spec.homepage

  spec.summary     = "Download, archive, and publish videos across social platforms"
  spec.description = "A command-line utility that keeps a local archive of your videos " \
                     "and distributes them across platforms. Download once. Archive " \
                     "forever. Publish anywhere."

  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb"] + %w[bin/bootleg README.md LICENSE]
  spec.bindir        = "bin"
  spec.executables   = ["bootleg"]
  spec.require_paths = ["lib"]

  spec.add_dependency "colorize"
  spec.add_dependency "csv"
  spec.add_dependency "nokogiri"
  spec.add_dependency "tzinfo", "~> 2.0"
end
