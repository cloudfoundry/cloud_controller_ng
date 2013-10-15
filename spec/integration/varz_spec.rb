require "spec_helper"

describe "Cloud Controller", :type => :integration do
  before(:all) do
    @authed_headers = {
      "Authorization" => "bearer #{admin_token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
    start_nats

    start_cc(config: "spec/fixtures/config/varz_config.yml")
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  it "reports number of users" do
    headers = {
      "Authorization" => "Basic #{Base64.encode64('varz:password')}"
    }

    count = 0

    make_get_request("/v2/users", @authed_headers) #check it -- we hit the API to make the mysterious user with guid-1

    sleep(1) #give varz a chance to populate

    make_get_request("/varz", headers, 7800).tap do |response|
      expect(JSON.parse(response.body)).to have_key("cc_user_count")
      count = JSON.parse(response.body)["cc_user_count"]
    end

    user_params = {
      "guid" => SecureRandom.uuid
    }

    response = make_post_request("/v2/users", user_params.to_json, @authed_headers)
    expect(response.code).to eql("201")

    sleep(1)

    make_get_request("/varz", headers, 7800).tap do |response|
      expect(JSON.parse(response.body)["cc_user_count"]).to eql(count + 1)
    end
  end
end