RSpec.describe Bootleg::Youtube::ScheduleBuilder do
  let(:config)    { Bootleg::Youtube::Config.new(category_id: "26", default_tags: %w[woodworking handtools],
                                                 publish_time: "19:00") }
  let(:downloads) { File.join(output_dir, "downloads").tap { |d| FileUtils.mkdir_p(d) } }
  let(:batch)     { File.join(output_dir, "batch") }
  let(:builder)   { described_class.new(config, out: StringIO.new) }

  def download(name, caption, audio: nil)
    base = File.join(downloads, name)
    text = "Title:       #{caption}\nVideo ID:    1\n"
    text += "Audio:       #{audio}\n" if audio
    File.write("#{base}.txt", text)
    File.write("#{base}.mp4", "video #{name}")
    base
  end

  def picks(text)
    described_class.parse_picks(text)
  end

  it "parses picks, ignoring blanks and comments" do
    parsed = picks("# header\n\n~/x/a.txt |  Title A \n/abs/b | B | with pipe\n")
    expect(parsed.map(&:to_a)).to eq([[File.expand_path("~/x/a.txt"), "Title A"], ["/abs/b", "B | with pipe"]])
  end

  it "rejects a pick without a title" do
    expect { picks("/abs/a\n") }.to raise_error(Bootleg::Error, /no '\| Title'/)
  end

  it "writes one row per day, copies the videos, and credits others' sounds" do
    a = download("someuser-2026-11-07-inlay-dovetails-pt-1", "Pt 1 #woodworking #dovetails #woodworking",
                 audio: "original sound - Steven K.")
    b = download("someuser-2026-11-08-some-days", "Some days", audio: "original sound - Me (own audio)")

    schedule = builder.build(picks("#{a} | Inlay Dovetails Pt. 1\n#{b}.txt | Some days"),
                             dir: batch, start: "2026-11-30")

    first, second = Bootleg::Youtube::Schedule.load(batch).entries
    expect(first.to_h).to eq(
      video_filename: "01-inlay-dovetails-pt-1.mp4", title: "Inlay Dovetails Pt. 1",
      description: "Pt 1 #woodworking #dovetails #woodworking\n\nOriginal sound by Steven K. (TikTok)",
      tags: "woodworking,dovetails,shorts", publish_date: "2026-11-30", publish_time: "19:00",
      privacy_status: "private", category_id: "26", made_for_kids: "false"
    )
    expect(second.to_h).to include(video_filename: "02-some-days.mp4", description: "Some days",
                                   tags: "woodworking,handtools,shorts", publish_date: "2026-12-01")
    expect(File.read(File.join(batch, "videos", "02-some-days.mp4"))).to eq("video someuser-2026-11-08-some-days")
    expect(schedule.path).to eq(File.join(batch, "schedule.csv"))
  end

  it "won't overwrite a schedule without force" do
    a = download("u-2026-11-07-a", "A")
    builder.build(picks("#{a} | A"), dir: batch, start: "2026-11-30")

    expect { builder.build(picks("#{a} | A"), dir: batch, start: "2026-11-30") }
      .to raise_error(Bootleg::Error, /already exists/)
    expect { builder.build(picks("#{a} | A"), dir: batch, start: "2026-12-01", force: true) }.not_to raise_error
  end

  it "checks every video exists before copying anything" do
    a = download("u-2026-11-07-a", "A")
    b = download("u-2026-11-08-b", "B")
    File.delete("#{b}.mp4")

    expect { builder.build(picks("#{a} | A\n#{b} | B"), dir: batch, start: "2026-11-30") }
      .to raise_error(Bootleg::Error, /Video not found/)
    expect(File.exist?(batch)).to be(false)
  end

  it "rejects a bad start date" do
    a = download("u-2026-11-07-a", "A")
    expect { builder.build(picks("#{a} | A"), dir: batch, start: "Dec 1") }
      .to raise_error(Bootleg::Error, /not YYYY-MM-DD/)
  end
end
