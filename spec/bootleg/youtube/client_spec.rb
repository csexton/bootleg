RSpec.describe Bootleg::Youtube::Client do
  let(:auth)     { instance_double(Bootleg::Youtube::Auth, access_token: "tok", refresh!: nil) }
  let(:http)     { FakeHttp.new }
  let(:sleeps)   { [] }
  let(:client)   { described_class.new(auth, http: http, sleeper: ->(s) { sleeps << s }) }
  let(:session)  { "https://upload.example/session/1" }
  let(:metadata) { { snippet: { title: "T" }, status: { privacyStatus: "private" } } }

  before { stub_const("#{described_class}::CHUNK_SIZE", 4) }

  def video(bytes)
    File.join(output_dir, "v.mp4").tap { |p| File.write(p, bytes) }
  end

  def responses(*list)
    list.each { |r| http.instance_variable_get(:@responses) << r }
  end

  describe "#insert_video" do
    it "starts a resumable session and sends the file in chunks" do
      responses(http_response(200, "", "Location" => session),
                http_response(308, "", "Range" => "bytes=0-3"),
                http_response(200, { id: "abc" }))
      progress = []

      result = client.insert_video(video("123456"), metadata) { |sent, total| progress << [sent, total] }

      expect(result).to eq("id" => "abc")
      start, first, second = http.requests
      expect(start.url).to include("uploadType=resumable", "part=snippet,status")
      expect(start.headers).to include("Authorization" => "Bearer tok", "X-Upload-Content-Length" => "6")
      expect(JSON.parse(start.body)).to eq("snippet" => { "title" => "T" }, "status" => { "privacyStatus" => "private" })
      expect([first.url, first.headers["Content-Range"], first.body]).to eq([session, "bytes 0-3/6", "1234"])
      expect([second.headers["Content-Range"], second.body]).to eq(["bytes 4-5/6", "56"])
      expect(progress).to eq([[4, 6], [6, 6]])
    end

    it "resumes from what the server has after a 5xx" do
      responses(http_response(200, "", "Location" => session),
                http_response(503),
                http_response(308, "", "Range" => "bytes=0-1"),
                http_response(308, "", "Range" => "bytes=0-5"),
                http_response(201, { id: "abc" }))

      expect(client.insert_video(video("12345678"), metadata)).to eq("id" => "abc")
      status_check = http.requests[2]
      expect(status_check.headers["Content-Range"]).to eq("bytes */8")
      expect(http.requests[3].headers["Content-Range"]).to eq("bytes 2-5/8")
      expect(http.requests[4].body).to eq("78")
      expect(sleeps).to eq([2])
    end

    it "retries a dropped connection" do
      responses(http_response(200, "", "Location" => session),
                Errno::ECONNRESET.new,
                http_response(308),
                http_response(200, { id: "abc" }))

      expect(client.insert_video(video("123"), metadata)).to eq("id" => "abc")
      expect(http.requests.last.headers["Content-Range"]).to eq("bytes 0-2/3")
    end

    it "surfaces quota errors with their reason" do
      responses(http_response(403, { error: { message: "Quota exceeded",
                                              errors: [{ reason: "quotaExceeded" }] } }))

      expect { client.insert_video(video("123"), metadata) }.to raise_error(Bootleg::Youtube::ApiError) { |e|
        expect(e.message).to include("HTTP 403", "Quota exceeded")
        expect(e).to be_quota
      }
    end

    it "refuses an empty file" do
      expect { client.insert_video(video(""), metadata) }.to raise_error(Bootleg::Error, /empty/)
    end
  end

  it "refreshes the token once on a 401" do
    responses(http_response(401), http_response(200, { items: [{ id: "a" }] }))

    expect(client.list_videos(%w[a b])).to eq([{ "id" => "a" }])
    expect(auth).to have_received(:refresh!).once
    expect(http.requests.first.url).to include("part=snippet", "id=a%2Cb")
  end

  it "updates a video" do
    responses(http_response(200, { id: "a" }))
    client.update_video({ id: "a", snippet: { description: "d" } })

    request = http.requests.first
    expect([request.method, request.url]).to eq([:put, "#{described_class::API_URL}/videos?part=snippet"])
    expect(JSON.parse(request.body)).to eq("id" => "a", "snippet" => { "description" => "d" })
  end
end
