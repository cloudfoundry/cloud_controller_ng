require 'spec_helper'

RSpec.describe 'Cloud Controller', type: :integration do
  before(:all) do
    start_nats
    start_cc
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  it 'responds to /varz with the expected keys' do
    varz_headers = {
      'Authorization' => "Basic #{Base64.encode64('varz:password')}"
    }

    make_get_request('/varz', varz_headers, 7800).tap do |response|
      response_hash = JSON.parse(response.body)
      expect(response_hash).to have_key('vcap_sinatra')
      expect(response_hash['vcap_sinatra']).to have_key('requests')
      expect(response_hash['vcap_sinatra']).to have_key('http_status')
      expect(response_hash['vcap_sinatra']).to have_key('recent_errors')
    end
  end
end
