$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "fileutils"
require "stringio"
require "tmpdir"
require "subetha"

# Helpers shared by the specs. Everything here stays offline: no spec may make
# a network request, so the HTTP layer is always stubbed out.
module SpecHelpers
  DEFAULT_CONFIG = {
    json_sidecar:      false,
    pages:             1,
    filename_username: true,
    filename_date:     true,
    filename_id:       false,
    filename_slug:     true
  }.freeze

  # An output directory that is removed after the example.
  def output_dir
    @output_dir ||= Dir.mktmpdir("subetha-spec")
  end

  def cleanup_output_dir
    FileUtils.rm_rf(@output_dir) if @output_dir
  end

  def config(**overrides)
    Subetha::Tiktok::Config.new(**DEFAULT_CONFIG, output_dir: output_dir, **overrides)
  end

  def files_in_output
    Dir.children(output_dir).sort
  end

  def read_output(name)
    File.read(File.join(output_dir, name))
  end

  # Post ids carry their creation time in the high 32 bits, so a spec that
  # wants a given date can mint an id for it.
  def id_for(time)
    ((time.to_i << 32) | 1).to_s
  end

  # The CLI chatters on both streams; specs capture it rather than print it.
  def captured_stdout
    $stdout.respond_to?(:string) ? $stdout.string : ""
  end

  def captured_stderr
    $stderr.respond_to?(:string) ? $stderr.string : ""
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
  config.after { cleanup_output_dir }

  config.around do |example|
    real_stdout = $stdout
    real_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    begin
      example.run
    ensure
      $stdout = real_stdout
      $stderr = real_stderr
    end
  end
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end
