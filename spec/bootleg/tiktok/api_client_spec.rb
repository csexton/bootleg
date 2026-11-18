RSpec.describe Bootleg::Tiktok::ApiClient do
  describe ".payload" do
    it "returns fields served at the top level" do
      expect(described_class.payload('{"status":"success","id":"7"}', "url"))
        .to eq("status" => "success", "id" => "7")
    end

    it "unwraps the older result envelope" do
      expect(described_class.payload('{"status":"success","result":{"id":"7"}}', "url"))
        .to eq("id" => "7")
    end

    it "surfaces the API's own error message" do
      expect { described_class.payload('{"status":"error","message":"Endpoint not found"}', "url") }
        .to raise_error(/Endpoint not found/)
    end

    it "falls back to the status when no message is given" do
      expect { described_class.payload('{"status":"rate_limited"}', "url") }
        .to raise_error(/rate_limited/)
    end

    it "rejects a non-JSON body" do
      expect { described_class.payload("<html>502 Bad Gateway</html>", "url") }
        .to raise_error(/invalid JSON/)
    end

    it "rejects a JSON body that is not an object" do
      expect { described_class.payload("[1, 2]", "url") }
        .to raise_error(/not an object/)
    end

    it "names the URL it was asked about" do
      expect { described_class.payload('{"status":"error"}', "https://tiktok/999") }
        .to raise_error(%r{https://tiktok/999})
    end
  end
end
