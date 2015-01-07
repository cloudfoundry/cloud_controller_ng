require 'spec_helper'
require 'nats/client'
require 'json'

describe 'NATS', type: :integration do
  before(:all) do
    start_nats debug: false, port: 4223
    start_cc debug: false, config: 'spec/fixtures/config/non_default_message_bus.yml'
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  describe 'When NATS fails' do
    before do
      kill_nats
    end

    it 'still works' do
      make_get_request('/info').tap do |r|
        expect(r.code).to eq('200')
      end
    end

    describe 'allowed requests' do
      let(:authorized_token) do
        {
          'Authorization' => "bearer #{admin_token}",
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
      end

      after do
        make_delete_request("/v2/organizations/#{@org_guid}?recursive=true", authorized_token) if @org_guid
      end

      it 'creates org, space and app in database' do
        data = %({"name":"nats-spec-org"})
        response = make_post_request('/v2/organizations', data, authorized_token)
        expect(response.code).to eql('201'), "Status is [#{response.code}], Body is [#{response.body}]"

        @org_guid = response.json_body['metadata']['guid']

        data = %({"organization_guid":"#{@org_guid}","name":"nats-spec-space"})
        response = make_post_request('/v2/spaces', data, authorized_token)
        expect(response.code).to eq('201')
        @space_guid = response.json_body['metadata']['guid']

        data = %({
          "space_guid" : "#{@space_guid}",
          "name" : "nats-spec-app",
          "instances" : 1,
          "production" : false,
          "buildpack" : null,
          "command" : null,
          "memory" : 256,
          "stack_guid" : null
        })

        response = make_post_request('/v2/apps', data, authorized_token)
        expect(response.code).to eq('201')
      end
    end
  end
end
