RSpec.describe Bootleg::Youtube::BatchUploader do
  let(:config)  { Bootleg::Youtube::Config.new(timezone: "America/New_York", delay: 45) }
  let(:client)  { instance_double(Bootleg::Youtube::Client) }
  let(:out)     { StringIO.new }
  let(:sleeps)  { [] }
  let(:schedule_path) { File.join(output_dir, "schedule.csv") }

  def entry(name, **fields)
    Bootleg::Youtube::Schedule::Entry.new(video_filename: name, title: "Title #{name}", description: "D",
                                          tags: "shorts", publish_date: "2026-11-17", publish_time: "19:00",
                                          privacy_status: "private", category_id: "26",
                                          made_for_kids: "false", **fields)
  end

  def build(entries, dry_run: false, files: entries.map(&:video_filename))
    FileUtils.mkdir_p(File.join(output_dir, "videos"))
    files.each { |f| File.write(File.join(output_dir, "videos", f), "video") }
    schedule = Bootleg::Youtube::Schedule.write(schedule_path, entries)
    @state   = Bootleg::Youtube::UploadState.for(schedule)
    described_class.new(schedule: schedule, state: @state, config: config, client: client,
                        dry_run: dry_run, out: out, sleeper: ->(s) { sleeps << s })
  end

  def quota_error
    Bootleg::Youtube::ApiError.new("quota", status: 403, reason: "quotaExceeded")
  end

  it "uploads each video, records it, and pauses only between uploads" do
    uploader = build([entry("a.mp4"), entry("b.mp4")])
    allow(client).to receive(:insert_video).and_return({ "id" => "ID1" }, { "id" => "ID2" })

    summary = uploader.run

    expect(summary.to_h).to include(uploaded: 2, skipped: 0, failed: 0, stopped: false)
    expect(client).to have_received(:insert_video)
      .with(File.join(output_dir, "videos", "a.mp4"),
            hash_including(status: hash_including(publishAt: "2026-11-17T19:00:00-05:00")))
    expect(sleeps).to eq([45])
    expect(@state.video_id("b.mp4")).to eq("ID2")
    expect(JSON.parse(File.read(File.join(output_dir, "uploads.json"))).keys).to eq(%w[a.mp4 b.mp4])
    expect(File.read(File.join(output_dir, "upload.log"))).to include("SUCCESS: a.mp4 -> https://youtu.be/ID1")
  end

  it "skips what is already uploaded, without pausing for it" do
    uploader = build([entry("a.mp4"), entry("b.mp4")])
    @state.record("a.mp4", video_id: "OLD")
    allow(client).to receive(:insert_video).and_return({ "id" => "ID2" })

    expect(uploader.run.to_h).to include(uploaded: 1, skipped: 1)
    expect(client).to have_received(:insert_video).once
    expect(sleeps).to be_empty
  end

  it "keeps going past a missing file and reports the failure" do
    uploader = build([entry("gone.mp4"), entry("b.mp4")], files: ["b.mp4"])
    allow(client).to receive(:insert_video).and_return({ "id" => "ID2" })

    summary = uploader.run
    expect(summary.to_h).to include(uploaded: 1, failed: 1)
    expect(summary).not_to be_ok
    expect(out.string).to include("FAILED: gone.mp4: Video file not found")
  end

  it "stops the batch when the quota runs out" do
    uploader = build([entry("a.mp4"), entry("b.mp4")])
    allow(client).to receive(:insert_video).and_raise(quota_error)

    summary = uploader.run
    expect(summary.to_h).to include(failed: 1, stopped: true)
    expect(client).to have_received(:insert_video).once
    expect(out.string).to include("quota is used up")
  end

  it "checks every row on a dry run without uploading or writing files" do
    uploader = build([entry("a.mp4"), entry("bad.mp4", privacy_status: "public")], dry_run: true)

    summary = uploader.run
    expect(summary.to_h).to include(uploaded: 1, failed: 1)
    expect(out.string).to include("DRY RUN: would upload a.mp4", "must be private")
    expect(Dir.children(output_dir)).not_to include("uploads.json", "upload.log")
  end
end
