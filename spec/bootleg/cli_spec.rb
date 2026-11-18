RSpec.describe Bootleg::CLI do
  it "prints usage and fails with no arguments" do
    expect(described_class.start([])).to eq(1)
    expect(captured_stdout).to include("Usage: bootleg PLATFORM")
  end

  it "prints the version" do
    expect(described_class.start(["--version"])).to eq(0)
    expect(captured_stdout.strip).to eq(Bootleg::VERSION)
  end

  it "rejects an unknown platform" do
    expect(described_class.start(["myspace"])).to eq(1)
    expect(captured_stderr).to include("Unknown platform: myspace")
  end

  it "hands the remaining arguments to the platform CLI" do
    expect(Bootleg::Tiktok::CLI).to receive(:start).with(["download", "URL"]).and_return(0)
    expect(described_class.start(["tiktok", "download", "URL"])).to eq(0)
  end
end
