shared_examples "an admin only endpoint" do |opts|
  it "returns an error for a regular user" do
    get opts[:path], {}, headers_for(VCAP::CloudController::User.make)
    last_response.status.should == 403
  end
end
