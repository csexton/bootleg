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

# Stands in for Youtube::Http: answers requests from a queue of responses
# and records what was asked.
class FakeHttp
  Request = Struct.new(:method, :url, :headers, :body)

  attr_reader :requests

  def initialize(*responses)
    @responses = responses
    @requests  = []
  end

  def request(method, url, headers: {}, body: nil)
    @requests << Request.new(method, url, headers, body)
    response = @responses.shift or raise "FakeHttp: unexpected #{method.upcase} #{url}"
    raise response if response.is_a?(Exception)

    response
  end
end

def http_response(code, body = "", headers = {})
  body = JSON.generate(body) unless body.is_a?(String)
  Subetha::Youtube::Response.new(code, headers.transform_keys(&:downcase), body)
end

RSpec.configure do |config|
  config.include SpecHelpers
  config.after { cleanup_output_dir }
  # Never read the real ~/.subetha.yml.
  config.before { allow(Subetha::ConfigFile).to receive(:candidates).and_return([]) }

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
