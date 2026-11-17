RSpec.describe Subetha::Tiktok::CLI do
  let(:video_url)   { "https://www.tiktok.com/@someuser/video/123" }
  let(:profile_url) { "https://www.tiktok.com/@someuser" }
  let(:processor)   { instance_double(Subetha::Tiktok::Processor, process: nil) }

  subject(:cli) { described_class.new }

  before do
    allow(cli).to receive(:pause)
    allow(Subetha::ConfigFile).to receive(:load).and_return({})
    allow(Subetha::Tiktok::Processor).to receive(:new).and_return(processor)
  end

  it "rejects an unknown command" do
    expect(cli.start(["upload", video_url])).to eq(1)
    expect(captured_stderr).to include("Unknown tiktok command: upload")
  end

  it "fails on an unknown option" do
    expect(cli.start(["download", "--bogus", video_url])).to eq(1)
    expect(captured_stderr).to include("invalid option: --bogus")
  end

  describe "download" do
    it "processes each URL with options applied to the config" do
      expect(cli.start(["download", "--output-dir", output_dir, "--json", "--id", video_url])).to eq(0)

      expect(Subetha::Tiktok::Processor).to have_received(:new) do |config|
        expect(config.output_dir).to eq(output_dir)
        expect(config.json_sidecar).to be(true)
        expect(config.filename_id).to be(true)
      end
      expect(processor).to have_received(:process).with(video_url)
    end

    it "keeps going after a failure and reports it" do
      other = "https://www.tiktok.com/@someuser/video/456"
      allow(processor).to receive(:process).with(video_url).and_raise("boom")

      expect(cli.start(["download", "--output-dir", output_dir, video_url, "not-a-url", other])).to eq(1)
      expect(processor).to have_received(:process).with(other)
      expect(captured_stderr).to include("Error: boom", "Skipping invalid URL: not-a-url",
                                         "Completed with 2 error(s)")
    end

    it "points profile URLs at the list command" do
      expect(cli.start(["download", "--output-dir", output_dir, profile_url])).to eq(1)
      expect(processor).not_to have_received(:process)
      expect(captured_stderr).to include("use `subetha tiktok list`")
    end
  end

  describe "list" do
    it "prints the profile's video URLs to stdout" do
      allow(Subetha::Tiktok::ProfileExtractor).to receive(:extract)
        .with(profile_url, pages: 2).and_return([video_url])

      expect(cli.start(["list", "--pages", "2", profile_url])).to eq(0)
      expect(captured_stdout).to eq("#{video_url}\n")
    end

    it "rejects a video URL" do
      expect(cli.start(["list", video_url])).to eq(1)
      expect(captured_stderr).to include("is not a profile URL")
    end
  end
end
