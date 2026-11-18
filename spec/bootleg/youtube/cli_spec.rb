RSpec.describe Bootleg::Youtube::CLI do
  subject(:cli) { described_class.new }

  it "rejects an unknown command" do
    expect(cli.start(["delete"])).to eq(1)
    expect(captured_stderr).to include("Unknown youtube command: delete")
  end

  it "reports bootleg errors as one line" do
    expect(cli.start(["upload", File.join(output_dir, "nope")])).to eq(1)
    expect(captured_stderr).to include("Error: Schedule not found")
  end

  it "requires --start for schedule" do
    expect(cli.start(["schedule", "picks.txt"])).to eq(1)
    expect(captured_stderr).to include("--start DATE is required")
  end

  it "dry-runs an upload without logging in" do
    FileUtils.mkdir_p(File.join(output_dir, "videos"))
    File.write(File.join(output_dir, "videos", "a.mp4"), "v")
    File.write(File.join(output_dir, "schedule.csv"),
               "video_filename,title,publish_date,publish_time,privacy_status\na.mp4,A,2026-12-01,19:00,private\n")
    expect(Bootleg::Youtube::Auth).not_to receive(:new)

    expect(cli.start(["upload", output_dir, "--dry-run"])).to eq(0)
    expect(captured_stdout).to include("DRY RUN: would upload a.mp4")
  end

  it "lists Shorts for the configured handle" do
    allow(Bootleg::ConfigFile).to receive(:load).and_return("youtube" => { "handle" => "@me" })
    allow(Bootleg::Youtube::ShortsLister).to receive(:titles).with("@me").and_return(["One", "Two"])

    expect(cli.start(["shorts"])).to eq(0)
    expect(captured_stdout).to eq("One\nTwo\n")
  end
end
