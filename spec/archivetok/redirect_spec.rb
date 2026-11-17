# Both the page fetcher and the downloader follow redirects, and both used to
# hand Location straight to URI.parse, which has no host when it is relative.
RSpec.describe "redirect handling" do
  let(:response_class) { Struct.new(:location) { def [](_key) = location } }
  let(:requested)      { URI.parse("https://v16.tiktok.com/dir/video.mp4?a=1") }

  shared_examples "a Location resolver" do
    def resolve(subject_object, location, requested)
      subject_object.send(:redirect_target, requested, response_class.new(location))
    end

    it "leaves an absolute URL alone" do
      expect(resolve(resolver, "https://cdn.example.com/x.mp4", requested))
        .to eq("https://cdn.example.com/x.mp4")
    end

    it "resolves a root-relative Location against the requested host" do
      expect(resolve(resolver, "/other/x.mp4", requested))
        .to eq("https://v16.tiktok.com/other/x.mp4")
    end

    it "resolves a path-relative Location against the requested directory" do
      expect(resolve(resolver, "x.mp4", requested))
        .to eq("https://v16.tiktok.com/dir/x.mp4")
    end

    it "resolves a protocol-relative Location" do
      expect(resolve(resolver, "//cdn.example.com/x.mp4", requested))
        .to eq("https://cdn.example.com/x.mp4")
    end

    it "raises a clear error when Location is missing" do
      expect { resolve(resolver, nil, requested) }
        .to raise_error(/no Location header/)
    end

    it "raises a clear error when Location is empty" do
      expect { resolve(resolver, "", requested) }
        .to raise_error(/no Location header/)
    end
  end

  describe Archivetok::Downloader do
    let(:resolver) { described_class.allocate }

    it_behaves_like "a Location resolver"
  end

  describe Archivetok::HtmlExtractor do
    let(:resolver) { described_class.allocate }

    it_behaves_like "a Location resolver"
  end
end
