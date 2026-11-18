RSpec.describe Bootleg::Tiktok::Processor do
  subject(:processor) { described_class.new(config) }

  # The shape the live endpoint returns today.
  let(:api_response) do
    {
      "status" => "success",
      "type"   => "video",
      "id"     => "7703941037248630030",
      "desc"   => "Woodworking Vocab: CA Glue",
      "video"  => "https://cdn.example/clip.mp4",
      "author" => { "nickname" => "C. Sexton", "uniqueId" => "deadrunwoodworks" },
      "images" => []
    }
  end

  describe "#normalize_api_video" do
    subject(:normalized) { processor.send(:normalize_api_video, api_response) }

    it "takes the handle from uniqueId" do
      expect(normalized[:author_id]).to eq("deadrunwoodworks")
    end

    it "takes the display name from nickname" do
      expect(normalized[:author_name]).to eq("C. Sexton")
    end

    it "accepts the video URL as a bare string" do
      expect(normalized[:video_url]).to eq("https://cdn.example/clip.mp4")
    end

    it "derives the creation time from the post id, which the API omits" do
      expect(Time.at(normalized[:create_time]).utc.strftime("%Y-%m-%d")).to eq("2026-11-03")
    end

    it "prefers an explicit createTime when the API does send one" do
      normalized = processor.send(:normalize_api_video, api_response.merge("createTime" => 1_700_000_000))
      expect(normalized[:create_time]).to eq(1_700_000_000)
    end

    it "raises rather than download nothing when no video URL is present" do
      expect { processor.send(:normalize_api_video, api_response.merge("video" => "")) }
        .to raise_error(/no video URL/)
    end
  end

  describe "#api_video_url" do
    it "reads the legacy playAddr string" do
      expect(processor.send(:api_video_url, "video" => { "playAddr" => "https://old/clip.mp4" }))
        .to eq("https://old/clip.mp4")
    end

    it "takes the first entry of a legacy playAddr list" do
      expect(processor.send(:api_video_url, "video" => { "playAddr" => ["https://old/a.mp4", "https://old/b.mp4"] }))
        .to eq("https://old/a.mp4")
    end

    it "returns nothing when the video key is missing" do
      expect(processor.send(:api_video_url, {})).to be_nil
    end
  end

  describe "#api_common" do
    it "still understands the legacy author.username key" do
      expect(processor.send(:api_common, "author" => { "username" => "legacy" })[:author_id])
        .to eq("legacy")
    end

    it "survives a response with no author at all" do
      expect(processor.send(:api_common, {})[:author_id]).to eq("")
    end
  end

  describe "#normalize_api_photo" do
    subject(:normalized) { processor.send(:normalize_api_photo, api_response) }

    it "keys the post as media rather than video" do
      expect(normalized).to include(media_id: "7703941037248630030")
      expect(normalized).not_to have_key(:video_id)
    end

    it "carries the same author and description as a video" do
      expect(normalized).to include(author_id: "deadrunwoodworks", description: "Woodworking Vocab: CA Glue")
    end
  end
end
