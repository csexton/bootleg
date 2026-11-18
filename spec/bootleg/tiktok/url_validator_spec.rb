RSpec.describe Bootleg::Tiktok::UrlValidator do
  describe ".valid?" do
    it "accepts a canonical video URL" do
      expect(described_class.valid?("https://www.tiktok.com/@user/video/123")).to be(true)
    end

    it "accepts a short vm.tiktok.com link" do
      expect(described_class.valid?("https://vm.tiktok.com/ZMabc123/")).to be(true)
    end

    it "accepts the bare domain without a subdomain" do
      expect(described_class.valid?("https://tiktok.com/@user/video/123")).to be(true)
    end

    it "rejects a lookalike domain that merely ends in tiktok.com" do
      expect(described_class.valid?("https://evil-tiktok.com/@user/video/123")).to be(false)
    end

    it "rejects a domain that only starts with tiktok.com" do
      expect(described_class.valid?("https://tiktok.com.example.net/@user/video/123")).to be(false)
    end

    it "rejects a non-string" do
      expect(described_class.valid?(nil)).to be(false)
    end
  end

  describe ".photo?" do
    it "recognises a photo post" do
      expect(described_class.photo?("https://www.tiktok.com/@user/photo/123")).to be(true)
    end

    it "does not treat a video as a photo post" do
      expect(described_class.photo?("https://www.tiktok.com/@user/video/123")).to be(false)
    end
  end

  describe ".profile?" do
    it "recognises a profile URL" do
      expect(described_class.profile?("https://www.tiktok.com/@deadrunwoodworks")).to be(true)
    end

    it "recognises a profile URL with a trailing slash" do
      expect(described_class.profile?("https://www.tiktok.com/@deadrunwoodworks/")).to be(true)
    end

    it "recognises handles containing dots" do
      expect(described_class.profile?("https://www.tiktok.com/@some.user")).to be(true)
    end

    it "does not treat a video URL as a profile" do
      expect(described_class.profile?("https://www.tiktok.com/@user/video/123")).to be(false)
    end

    it "returns false for an unparseable URL rather than raising" do
      expect(described_class.profile?("http://[bad")).to be(false)
    end
  end
end
