RSpec.describe Subetha::Youtube::DescriptionUpdater do
  let(:client) { instance_double(Subetha::Youtube::Client, update_video: {}) }
  let(:out)    { StringIO.new }

  def entry(name, description)
    Subetha::Youtube::Schedule::Entry.new(video_filename: name, title: name, description: description)
  end

  let(:schedule) do
    Subetha::Youtube::Schedule.new(File.join(output_dir, "schedule.csv"),
                                   [entry("same", "Same"), entry("changed", "New\n\nCredit"),
                                    entry("new", "x"), entry("deleted", "y")])
  end
  let(:state) do
    Subetha::Youtube::UploadState.new(File.join(output_dir, "uploads.json")).tap do |s|
      s.record("same", video_id: "S")
      s.record("changed", video_id: "C")
      s.record("deleted", video_id: "D")
    end
  end

  before do
    allow(client).to receive(:list_videos).with(%w[S C D]).and_return([
      { "id" => "S", "snippet" => { "title" => "same", "description" => "Same " } },
      { "id" => "C", "snippet" => { "title" => "T", "categoryId" => "26", "tags" => ["t"],
                                    "description" => "Old", "channelId" => "ignored" } }
    ])
  end

  it "updates only the descriptions that differ, keeping the rest of the snippet" do
    changed = described_class.new(schedule: schedule, state: state, client: client, out: out).run

    expect(changed).to eq(1)
    expect(client).to have_received(:update_video).once.with(
      id: "C", snippet: { "title" => "T", "categoryId" => "26", "tags" => ["t"],
                          "description" => "New\n\nCredit" }
    )
    expect(out.string).to include("=  S same: already up to date", "-  new: not uploaded",
                                  "!  D deleted: not found on YouTube")
  end

  it "changes nothing on a dry run" do
    changed = described_class.new(schedule: schedule, state: state, client: client,
                                  dry_run: true, out: out).run

    expect(changed).to eq(1)
    expect(client).not_to have_received(:update_video)
    expect(out.string).to include("~  C changed: would set description")
  end
end
