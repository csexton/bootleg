RSpec.describe Subetha::Tiktok::Sidecar do
  def write(name, text)
    File.join(output_dir, name).tap { |path| File.write(path, text) }
  end

  it "reads a .txt sidecar, including a caption that spans lines" do
    path = write("post.txt", <<~TXT)
      Title:       First line #woodworking
      second line
      Author:      Some User (@someuser)
      Date:        2026-11-07
      Video ID:    7709106040935124237
      Source URL:  https://www.tiktok.com/@someuser/video/7709106040935124237
      Audio:       original sound - Steven K.
      Audio URL:   https://www.tiktok.com/music/original-sound-1
    TXT

    sidecar = described_class.new(path)
    expect(sidecar.title).to eq("First line #woodworking\nsecond line")
    expect(sidecar.date).to eq("2026-11-07")
    expect(sidecar.video_id).to eq("7709106040935124237")
    expect(sidecar.audio_label).to eq("original sound - Steven K.")
    expect(sidecar.video_path).to eq(File.join(output_dir, "post.mp4"))
  end

  it "reads a .json sidecar and labels its audio like the .txt form" do
    path = write("post.json", JSON.generate(
      title: "Caption", author: { name: "Me", username: "me" }, date: "2026-11-07",
      video_id: "42", source_url: "https://www.tiktok.com/@me/video/42",
      audio: { title: "original sound", artist: "Me", original: true, own: true, id: "1", url: nil }
    ))

    sidecar = described_class.new(path)
    expect(sidecar.title).to eq("Caption")
    expect(sidecar.video_id).to eq("42")
    expect(sidecar.audio_label).to eq("original sound - Me (own audio)")
  end

  it "has no audio label for sidecars written before audio was recorded" do
    path = write("old.txt", "Title:       Caption\nVideo ID:    1\n")
    expect(described_class.new(path).audio_label).to be_nil
  end

  describe ".find" do
    it "accepts the base path with or without an extension, preferring .txt" do
      write("post.txt", "Title: from txt\n")
      write("post.json", '{"title":"from json"}')
      base = File.join(output_dir, "post")

      expect(described_class.find(base).title).to eq("from txt")
      expect(described_class.find("#{base}.mp4").title).to eq("from txt")
    end

    it "raises when there is no sidecar" do
      expect { described_class.find(File.join(output_dir, "nope")) }
        .to raise_error(Subetha::Error, /No sidecar/)
    end
  end
end
