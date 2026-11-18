RSpec.describe Bootleg::Youtube::Schedule do
  let(:entry_class) { described_class::Entry }

  def entry(**fields)
    entry_class.new(video_filename: "01.mp4", title: "Title", description: "Desc",
                    tags: "a, b,,shorts", publish_date: "2026-11-17", publish_time: "19:00",
                    privacy_status: "private", category_id: "26", made_for_kids: "false", **fields)
  end

  describe "Entry#publish_at" do
    it "uses the zone's offset on that date" do
      expect(entry.publish_at("America/New_York")).to eq("2026-11-17T19:00:00-05:00")
      expect(entry(publish_date: "2026-07-17").publish_at("America/New_York"))
        .to eq("2026-07-17T19:00:00-04:00")
    end

    it "accepts HH:MM:SS" do
      expect(entry(publish_time: "07:30:15").publish_at("Asia/Kolkata"))
        .to eq("2026-11-17T07:30:15+05:30")
    end

    it "is nil for an unscheduled row" do
      expect(entry(publish_date: "").publish_at("UTC")).to be_nil
    end

    it "rejects a time skipped by a DST change" do
      expect { entry(publish_date: "2026-03-08", publish_time: "02:30").publish_at("America/New_York") }
        .to raise_error(Bootleg::Error, /does not exist/)
    end

    it "rejects a malformed date" do
      expect { entry(publish_date: "11/17/2026").publish_at("UTC") }
        .to raise_error(Bootleg::Error, /not YYYY-MM-DD/)
    end
  end

  describe "Entry#metadata" do
    it "builds the videos.insert body" do
      expect(entry.metadata("UTC")).to eq(
        snippet: { title: "Title", description: "Desc", tags: %w[a b shorts], categoryId: "26" },
        status:  { privacyStatus: "private", selfDeclaredMadeForKids: false,
                   publishAt: "2026-11-17T19:00:00+00:00" }
      )
    end

    it "refuses to schedule a video that isn't private" do
      expect { entry(privacy_status: "public").metadata("UTC") }
        .to raise_error(Bootleg::Error, /must be private/)
    end

    it "uploads an unscheduled row with its own privacy and no publishAt" do
      status = entry(publish_date: "", privacy_status: "Unlisted").metadata("UTC")[:status]
      expect(status).to eq(privacyStatus: "unlisted", selfDeclaredMadeForKids: false)
    end
  end

  describe ".load" do
    it "reads youtube-shorts-scheduler CSVs, given the file or its directory" do
      File.write(File.join(output_dir, "schedule.csv"), <<~CSV)
        video_filename,title,description,tags,publish_date,publish_time,privacy_status,category_id,made_for_kids
        01.mov,"My Title","Line one
        line two","tag1,tag2,shorts",2026-07-26,19:00:00,private,27,false
      CSV

      schedule = described_class.load(output_dir)
      expect(schedule.entries.size).to eq(1)
      expect(schedule.entries.first.description).to eq("Line one\nline two")
      expect(schedule.video_path(schedule.entries.first)).to eq(File.join(output_dir, "videos", "01.mov"))
      expect(schedule.video_path(schedule.entries.first, "/v")).to eq("/v/01.mov")
    end

    it "explains a missing file or column" do
      expect { described_class.load(File.join(output_dir, "nope.csv")) }
        .to raise_error(Bootleg::Error, /Schedule not found/)

      File.write(File.join(output_dir, "bad.csv"), "title\nx\n")
      expect { described_class.load(File.join(output_dir, "bad.csv")) }
        .to raise_error(Bootleg::Error, /missing column\(s\): video_filename/)
    end
  end

  it "round-trips through .write" do
    path = File.join(output_dir, "schedule.csv")
    described_class.write(path, [entry(description: "multi\nline, \"quoted\"")])
    expect(described_class.load(path).entries.first.to_h).to eq(entry(description: "multi\nline, \"quoted\"").to_h)
  end
end
