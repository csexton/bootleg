RSpec.describe Subetha::Youtube::ShortsLister do
  let(:html) do
    '{"accessibilityText":"Inlay Dovetails Pt. 1, 1.2K views - play Short"},' \
      '{"accessibilityText":"The sound of flat: \"thunk\" & more, 845 views - play Short"},' \
      '{"accessibilityText":"Not a short"}'
  end

  it "pulls titles from the Shorts tab, decoding JSON escapes" do
    http = FakeHttp.new(http_response(200, html))

    expect(described_class.titles("someuser", http: http))
      .to eq(["Inlay Dovetails Pt. 1", 'The sound of flat: "thunk" & more'])
    expect(http.requests.first.url).to eq("https://www.youtube.com/@someuser/shorts")
  end

  it "follows a redirect (e.g. a consent page)" do
    http = FakeHttp.new(http_response(302, "", "Location" => "/@someuser/shorts?ok=1"),
                        http_response(200, html))

    expect(described_class.titles("@someuser", http: http).size).to eq(2)
    expect(http.requests.last.url).to eq("https://www.youtube.com/@someuser/shorts?ok=1")
  end

  it "reports an HTTP failure" do
    http = FakeHttp.new(http_response(404))
    expect { described_class.titles("@nobody", http: http) }.to raise_error(Subetha::Error, /HTTP 404/)
  end
end
