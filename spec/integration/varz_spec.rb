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

  it 'reports number of users' do
    count = 0

    make_get_request('/v2/users', auth_headers) #check it -- we hit the API to make the mysterious user with guid-1

    sleep(1) #give varz a chance to populate

    make_get_request('/varz', varz_headers, 7800).tap do |response|
      expect(JSON.parse(response.body)).to have_key('cc_user_count')
      count = JSON.parse(response.body)['cc_user_count']
    end

    response = make_post_request('/v2/users', user_params.to_json, auth_headers)
    expect(response.code).to eql('201')

    sleep(1)

    make_get_request('/varz', varz_headers, 7800).tap do |response|
      expect(JSON.parse(response.body)['cc_user_count']).to eql(count + 1)
    end
  end

  it 'reports the length of CC job queue' do
    cc_job_queue_length = nil

    response = make_post_request('/v2/users', user_params.to_json, auth_headers)
    expect(response.code).to eql('201')

    # Async deletion creates a delayed job
    response = make_delete_request("/v2/users/#{user_guid}?async=true", auth_headers)
    expect(response.code).to eql('202')

    sleep 1

    make_get_request('/varz', varz_headers, 7800).tap do |response|
      expect(JSON.parse(response.body)).to have_key('cc_job_queue_length')
      cc_job_queue_length = JSON.parse(response.body)['cc_job_queue_length']
    end

    expect(cc_job_queue_length['cc-generic']).to eq(1)
  end
end
