module UAARequests
  def self.stub_all
    # stub token request
    WebMock::API.stub_request(:post, "http://cc-service-dashboards:some-sekret@localhost:8080/uaa/oauth/token").to_return(
      status:  200,
      body:    { token_type: "token-type", access_token: "access-token" }.to_json,
      headers: { "content-type" => "application/json" })

    # stub client search request
    WebMock::API.stub_request(:get, "http://localhost:8080/uaa/oauth/clients/dash-id").to_return(status: 404)

    # stub client create request
    WebMock::API.stub_request(:post, "http://localhost:8080/uaa/oauth/clients/tx/modify").to_return(
      status:  201,
      body:    { id: "some-id", client_id: "dash-id" }.to_json,
      headers: { "content-type" => "application/json" })
  end
end
