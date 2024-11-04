# Copyright (c) 2009-2011 VMware, Inc.
require 'httpclient'

require 'vcap/services/api/const'

module VCAP
  module Services
    module Api
    end
  end
end

module VCAP::Services::Api
  module SynchronousHttpRequest
    def self.request(url, token, verb, _timeout, msg=VCAP::Services::Api::EMPTY_REQUEST)
      header = {
        VCAP::Services::Api::GATEWAY_TOKEN_HEADER => token,
        'Content-Type' => 'application/json'
      }
      body = msg.encode
      client = HTTPClient.new
      msg = client.request(verb.to_sym, url, body:, header:)
      [msg.code, msg.body]
    end
  end
end
