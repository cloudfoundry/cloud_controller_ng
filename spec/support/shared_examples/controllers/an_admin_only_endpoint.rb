shared_examples "an admin only endpoint" do |opts|
  it "returns an error for a regular user" do
    get opts[:path], {}, headers_for(VCAP::CloudController::User.make)
    expect(last_response.status).to eq(403)
  end
end
