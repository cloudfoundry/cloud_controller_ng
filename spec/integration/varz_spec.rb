require 'spec_helper'

describe 'Cloud Controller', :type => :integration do
  let(:auth_headers) do
    {
      'Authorization' => "bearer #{admin_token}",
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }
  end

  let(:varz_headers) do
    {
      'Authorization' => "Basic #{Base64.encode64('varz:password')}"
    }
  end

  let(:user_guid) { SecureRandom.uuid }

  let(:user_params) do
    {
      'guid' => user_guid
    }
  end

  before(:all) do
    start_nats
    start_cc(config: 'spec/fixtures/config/varz_config.yml')
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  it 'responds to /varz with the expected keys' do
    make_get_request('/varz', varz_headers, 7800).tap do |response|
      response_hash = JSON.parse(response.body)
      expect(response_hash).to have_key('vcap_sinatra')
      expect(response_hash['vcap_sinatra']).to have_key('requests')
      expect(response_hash['vcap_sinatra']).to have_key('http_status')
      expect(response_hash['vcap_sinatra']).to have_key('recent_errors')
    end
  end
end
