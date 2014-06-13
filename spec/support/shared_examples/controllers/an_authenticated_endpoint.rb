shared_examples "an authenticated endpoint" do |opts|
  it "returns an error when the auth header is invalid" do
    headers = headers_for(VCAP::CloudController::User.make)
    headers["HTTP_AUTHORIZATION"] += "EXTRA STUFF"
    get opts[:path], {}, headers

    expect(last_response.status).to eq 401
    expect(decoded_response["code"]).to eq 1000

  end

  it "succeeds for a regular user" do
    get opts[:path], {}, headers_for(VCAP::CloudController::User.make)
    last_response.status.should == 200
  end
end

shared_examples "an admin only endpoint" do |opts|
  it "returns an error when the auth header is invalid" do
    headers = headers_for(VCAP::CloudController::User.make)
    headers["HTTP_AUTHORIZATION"] += "EXTRA STUFF"
    get opts[:path], {}, headers

    expect(last_response.status).to eq 401
    expect(decoded_response["code"]).to eq 1000

  end

  it "returns an error for a regular user" do
    get opts[:path], {}, headers_for(VCAP::CloudController::User.make)
    last_response.status.should == 403
  end

  it "succeeds for an admin" do
    get opts[:path], {}, headers_for(nil, admin_scope: true)
    last_response.status.should == 200
  end
end
