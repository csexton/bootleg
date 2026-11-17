require_relative "lib/archivetok/version"

Gem::Specification.new do |s|
  s.name        = "archivetok"
  s.version     = Archivetok::VERSION
  s.summary     = "CLI tool to download TikTok videos and photos"
  s.license     = "MIT"
  s.authors     = ["archivetok"]
  s.executables = ["archivetok"]
  s.files       = Dir["lib/**/*.rb", "bin/*"] + ["README.md", "LICENSE"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.0"

  s.add_dependency "nokogiri"
  s.add_dependency "colorize"

  s.add_development_dependency "rspec", "~> 3.13"
end
