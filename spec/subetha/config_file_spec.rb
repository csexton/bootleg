RSpec.describe Subetha::ConfigFile do
  around do |example|
    Dir.mktmpdir("subetha-config") do |dir|
      Dir.chdir(dir) { example.run }
    end
  end

  before do
    # Keep a real ~/.subetha.yml out of the examples.
    allow(described_class).to receive(:candidates)
      .and_return([File.join(Dir.pwd, ".subetha.yml")])
  end

  it "returns an empty section when there is no file" do
    expect(described_class.section("tiktok")).to eq({})
  end

  it "returns the settings under the platform's key" do
    File.write(".subetha.yml", "tiktok:\n  output_dir: ~/tt\n  pages: 3\nyoutube:\n  privacy: private\n")
    expect(described_class.section("tiktok")).to eq("output_dir" => "~/tt", "pages" => 3)
  end

  it "tolerates an empty file or a non-hash section" do
    File.write(".subetha.yml", "")
    expect(described_class.section("tiktok")).to eq({})

    File.write(".subetha.yml", "tiktok: nope\n")
    expect(described_class.section("tiktok")).to eq({})
  end
end
