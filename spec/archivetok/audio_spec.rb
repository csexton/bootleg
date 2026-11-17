RSpec.describe Archivetok::Audio do
  # Shape taken from a real post (the shellac video) that used someone else's audio.
  let(:borrowed) do
    { "id" => "7530081457067920142", "title" => "original sound",
      "authorName" => "aubory bugg", "original" => true }
  end

  describe ".from" do
    it "credits another creator's original sound" do
      expect(described_class.from(borrowed, "C. Sexton")).to include(
        title: "original sound", artist: "aubory bugg", own: false,
        url: "https://www.tiktok.com/music/original-sound-7530081457067920142"
      )
    end

    it "marks an original sound under the poster's own name as their own" do
      raw = borrowed.merge("authorName" => "C. Sexton")
      expect(described_class.from(raw, "c. sexton")[:own]).to be(true)
    end

    it "never calls a licensed track the poster's own" do
      raw = { "id" => "1", "title" => "Song", "authorName" => "C. Sexton", "original" => false }
      expect(described_class.from(raw, "C. Sexton")[:own]).to be(false)
    end

    it "accepts the API's author key" do
      expect(described_class.from({ "title" => "Song", "author" => "Band" }, "x")[:artist]).to eq("Band")
    end

    it "ignores missing or empty audio" do
      expect(described_class.from(nil, "x")).to be_nil
      expect(described_class.from("a string", "x")).to be_nil
      expect(described_class.from({ "id" => "1" }, "x")).to be_nil
    end

    it "omits the URL when there is no sound id" do
      expect(described_class.from({ "title" => "Song" }, "x")[:url]).to be_nil
    end
  end

  describe ".label" do
    it "joins title and artist, noting the poster's own audio" do
      expect(described_class.label(described_class.from(borrowed, "C. Sexton")))
        .to eq("original sound - aubory bugg")
      expect(described_class.label(described_class.from(borrowed, "aubory bugg")))
        .to eq("original sound - aubory bugg (own audio)")
    end

    it "does not repeat an artist already in the title" do
      audio = described_class.from({ "title" => "original sound - Hunny Hints", "authorName" => "Hunny Hints" }, "x")
      expect(described_class.label(audio)).to eq("original sound - Hunny Hints")
    end
  end
end
