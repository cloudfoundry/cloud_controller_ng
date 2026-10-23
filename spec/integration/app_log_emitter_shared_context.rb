require 'spec_helper'

RSpec.shared_context 'Cloud controller Loggregator Integration' do
  before(:all) do
    @authed_headers = {
      'Authorization' => "bearer #{admin_token}",
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }

    @loggregator_server = FakeLoggregatorServer.new(3456)
    @loggregator_server.start

    org = org_with_default_quota(@authed_headers)
    org_guid = org.json_body['metadata']['guid']

    space = make_post_request('/v2/spaces',
                              {
                                'name' => 'foo_space',
                                'organization_guid' => org_guid
                              }.to_json,
                              @authed_headers)
    @space_guid = space.json_body['metadata']['guid']
  end

  after(:all) do
    @loggregator_server.stop
  end

  it 'sends logs to the loggregator' do
    app = make_post_request('/v2/apps',
                            {
                              'name' => 'foo_app',
                              'space_guid' => @space_guid
                            }.to_json,
                            @authed_headers)

    app_id = app.json_body['metadata']['guid']
    messages = @loggregator_server.messages

    expect(messages.size).to eq(1)

    message = messages.first
    expect(message.source_id).to eq(app_id)
    expect(message.log.type).to eq(:OUT)
    expect(message.log.payload).to eq("Created app with guid #{app_id}")
    expect(message.tags['source_type']).to eq('API')
  end
end
