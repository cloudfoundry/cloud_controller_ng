require "net/http"
require "uri"

module IntegrationHttp
  def admin_token
    token = {
      "aud" => "cloud_controller",
      "exp" => Time.now.to_i + 10_000,
      "client_id" => Sham.guid,
      "scope" => ["cloud_controller.admin"],
    }
    CF::UAA::TokenCoder.encode(token, :skey => "tokensecret", :algorithm => "HS256")
  end

  module JsonBody
    def json_body
      @json_body ||= JSON.parse(body)
    end
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

    response.extend(JsonBody)
    response
  end
end

RSpec.configure do |rspec_config|
  rspec_config.include(IntegrationHttp, :type => :integration)
end
