require "spec_helper"
require "net/http"
require "uri"

describe "Cloud controller", :type => :integration do
  start_nats
  start_cc

  it "responds to /info" do
    make_http_request("/info").tap do |r|
      r.code.should == "200"
      r.json_body["version"].should == 2
    end
  end

  it "authenticate and authorize with valid token" do
    unauthorized_token = {"Authorization" => "bearer unauthorized-token"}
    make_http_request("/v2/stacks", unauthorized_token).tap do |r|
      r.code.should == "401"
    end

    authorized_token = {"Authorization" => "bearer #{admin_token}"}
    make_http_request("/v2/stacks", authorized_token).tap do |r|
      r.code.should == "200"
      r.json_body["resources"].should be_a(Array)
    end
  end

  def admin_token
    token = {
      "aud" => "cloud_controller",
      "exp" => Time.now.to_i + 10_000,
      "client_id" => Sham.guid,
      "scope" => ["cloud_controller.admin"],
    }
    CF::UAA::TokenCoder.encode(token, :skey => "tokensecret", :algorithm => "HS256")
  end

  def make_http_request(path, headers = {})
    url = URI.parse("http://localhost:8181#{path}")

    response = Net::HTTP.new(url.host, url.port).start do |http|
      request = Net::HTTP::Get.new(url.path)
      headers.each do |name, value|
        request.add_field(name, value)
      end
      http.request(request)
    end

    response.extend(Module.new do
      def json_body
        @json_body ||= JSON.parse(body)
      end
    end)

    response
  end
end
