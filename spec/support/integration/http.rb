require 'net/http'
require 'uri'

module IntegrationHttp
  def admin_token
    token = {
      'aud' => 'cloud_controller',
      'exp' => Time.now.utc.to_i + 10_000,
      'client_id' => Sham.guid,
      'scope' => ['cloud_controller.admin'],
    }
    CF::UAA::TokenCoder.encode(token, skey: 'tokensecret', algorithm: 'HS256')
  end

  module JsonBody
    def json_body
      @json_body ||= JSON.parse(body)
    end
  end

  def make_get_request(path, headers={}, port=8181)
    url = URI.parse("http://localhost:#{port}#{path}")

    response = Net::HTTP.new(url.host, url.port).start do |http|
      request = Net::HTTP::Get.new(url.request_uri)
      headers.each do |name, value|
        request.add_field(name, value)
      end
      http.request(request)
    end

    response.extend(JsonBody)
    response
  end

  def make_post_request(path, data, headers={}, port=8181)
    http = Net::HTTP.new('localhost', port)
    response = http.post(path, data, headers)
    response.extend(JsonBody)
    response
  end

  def make_put_request(path, data, headers={})
    http = Net::HTTP.new('localhost', '8181')
    response = http.put(path, data, headers)
    response.extend(JsonBody)
    response
  end

  def make_delete_request(path, headers={})
    http = Net::HTTP.new('localhost', '8181')
    response = http.delete(path, headers)
    response.extend(JsonBody)
    response
  end
end
