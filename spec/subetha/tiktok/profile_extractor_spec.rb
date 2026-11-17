RSpec.describe Subetha::Tiktok::ProfileExtractor do
  let(:profile_url) { "https://www.tiktok.com/@deadrunwoodworks" }

  def item(id, created_at)
    { "id" => id.to_s, "createTime" => created_at, "author" => { "uniqueId" => "deadrunwoodworks" } }
  end

  describe "#extract" do
    subject(:extractor) { described_class.new(profile_url, pages: 2) }

    # Timestamps must sit above TIKTOK_EPOCH_MS or paging stops after one page.
    let(:page_one) do
      { "itemList" => [item(1, 1_780_662_900), item(2, 1_780_662_800), item(3, 1_780_662_706)],
        "hasMorePrevious" => true }
    end
    # The cursor is the last item's createTime and the API treats it as
    # inclusive, so item 3 arrives a second time.
    let(:page_two) do
      { "itemList" => [item(3, 1_780_662_706), item(4, 1_780_662_600)],
        "hasMorePrevious" => false }
    end

    before do
      allow(extractor).to receive(:fetch_html).and_return("<html></html>")
      allow(extractor).to receive(:parse_rehydration_json).and_return(
        "__DEFAULT_SCOPE__" => { "webapp.user-detail" => { "userInfo" => { "user" => { "secUid" => "SEC" } } } }
      )
      allow(extractor).to receive(:request_page).and_return(page_one, page_two)
    end

    it "returns each post once despite the repeated page boundary" do
      expect(extractor.extract).to eq(
        %w[1 2 3 4].map { |id| "https://www.tiktok.com/@deadrunwoodworks/video/#{id}" }
      )
    end

    it "preserves the order the API returned" do
      expect(extractor.extract.map { |url| url[/\d+\z/] }).to eq(%w[1 2 3 4])
    end

    it "returns nothing when the profile page cannot be parsed" do
      allow(extractor).to receive(:parse_rehydration_json).and_return(nil)

      expect(extractor.extract).to eq([])
    end

    it "returns nothing when the profile has no secUid" do
      allow(extractor).to receive(:parse_rehydration_json).and_return("__DEFAULT_SCOPE__" => {})

      expect(extractor.extract).to eq([])
    end
  end

  describe "#fetch_page" do
    subject(:extractor) { described_class.new(profile_url) }

    let(:page) { { "itemList" => [item(1, 1_780_662_900)] } }

    def device_ids_seen(responses)
      seen = []
      allow(extractor).to receive(:request_page) do
        seen << extractor.instance_variable_get(:@device_id)
        responses.shift
      end
      [extractor.send(:fetch_page, "SEC", 1_780_662_900_000), seen]
    end

    it "retries after the API rejects a device_id" do
      result, seen = device_ids_seen([:empty_body, page])

      expect(result).to eq(page)
      expect(seen.size).to eq(2)
    end

    it "uses a fresh device_id on each retry" do
      _result, seen = device_ids_seen([:empty_body, :empty_body, page])

      expect(seen.uniq.size).to eq(seen.size)
    end

    it "gives up after MAX_DEVICE_ID_RETRIES rerolls" do
      result, seen = device_ids_seen([:empty_body] * 5)

      expect(result).to be_nil
      expect(seen.size).to eq(described_class::MAX_DEVICE_ID_RETRIES + 1)
    end

    it "does not retry failures that are not an empty body" do
      result, seen = device_ids_seen([nil, page])

      expect(result).to be_nil
      expect(seen.size).to eq(1)
    end
  end
end
