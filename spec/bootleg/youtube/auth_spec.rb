RSpec.describe Bootleg::Youtube::Auth do
  let(:config) do
    Bootleg::Youtube::Config.new(client_secrets: File.join(output_dir, "client_secrets.json"),
                                 token_path:     File.join(output_dir, "youtube", "token.json"))
  end
  let(:http) { FakeHttp.new }
  let(:auth) { described_class.new(config, http: http, out: StringIO.new) }

  before do
    File.write(config.client_secrets,
               JSON.generate(installed: { client_id: "cid", client_secret: "shh",
                                          token_uri: "https://oauth2.example/token" }))
  end

  def save_token(**fields)
    FileUtils.mkdir_p(File.dirname(config.token_path))
    File.write(config.token_path, JSON.generate(fields))
  end

  it "asks for a login when there is no token" do
    expect { auth.access_token }.to raise_error(Bootleg::Error, /bootleg youtube auth/)
  end

  it "uses a token that hasn't expired" do
    save_token(access_token: "live", refresh_token: "r", expires_at: Time.now.to_i + 3600)
    expect(auth.access_token).to eq("live")
    expect(http.requests).to be_empty
  end

  it "refreshes an expired token and keeps the refresh token" do
    save_token(access_token: "old", refresh_token: "r", expires_at: Time.now.to_i - 1)
    http.instance_variable_get(:@responses) << http_response(200, { access_token: "new", expires_in: 3599 })

    expect(auth.access_token).to eq("new")
    request = http.requests.first
    expect(request.url).to eq("https://oauth2.example/token")
    expect(URI.decode_www_form(request.body).to_h)
      .to include("grant_type" => "refresh_token", "refresh_token" => "r", "client_id" => "cid")

    saved = JSON.parse(File.read(config.token_path))
    expect(saved).to include("access_token" => "new", "refresh_token" => "r")
    expect(File.stat(config.token_path).mode & 0o777).to eq(0o600)
  end

  it "explains an expired login" do
    save_token(access_token: "old", refresh_token: "r", expires_at: 0)
    http.instance_variable_get(:@responses) << http_response(400, { error: "invalid_grant",
                                                                    error_description: "Token has been expired" })

    expect { auth.access_token }.to raise_error(Bootleg::Error, /expired or was revoked.*bootleg youtube auth/)
  end

  it "builds a PKCE authorization URL asking for upload and edit scopes" do
    url    = auth.authorization_url("http://127.0.0.1:9/", "verifier", "st")
    params = URI.decode_www_form(URI.parse(url).query).to_h

    expect(url).to start_with(described_class::AUTH_URI)
    expect(params).to include("client_id" => "cid", "redirect_uri" => "http://127.0.0.1:9/",
                              "access_type" => "offline", "code_challenge_method" => "S256",
                              "state" => "st", "scope" => described_class::SCOPES.join(" "))
    expect(params["code_challenge"]).to eq("iMnq5o6zALKXGivsnlom_0F5_WYda32GHkxlV7mq7hQ")
  end

  it "points at Google Cloud Console when the client secrets are missing" do
    File.delete(config.client_secrets)
    expect { auth.authorization_url("x", "v", "s") }.to raise_error(Bootleg::Error, /client secrets not found/)
  end
end
