require 'spec_helper'
require 'securerandom'

RSpec.describe 'Cloud controller Loggregator Integration', type: :integration do
  before(:all) do
    @loggregator_server = FakeLoggregatorServer.new(12345)
    @loggregator_server.start

    @authed_headers = {
        'Authorization' => "bearer #{admin_token}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
    }

    start_cc(debug: false, config: 'spec/fixtures/config/port_8181_config.yml')

    org = org_with_default_quota(@authed_headers)
    org_guid = org.json_body['metadata']['guid']

    space = make_post_request('/v2/spaces',
      {
        'name' => 'foo_space',
        'organization_guid' => org_guid
      }.to_json,
      @authed_headers
    )
    @space_guid = space.json_body['metadata']['guid']
  end

  after(:all) do
    stop_cc
    @loggregator_server.stop
  end

  it 'send logs to the loggregator' do
    app = make_post_request('/v2/apps',
      {
        'name' => 'foo_app',
        'space_guid' => @space_guid
      }.to_json,
      @authed_headers
    )

    app_id = app.json_body['metadata']['guid']
    messages = @loggregator_server.messages

    expect(messages.size).to eq(1)

    message = messages.first
    expect(message.message).to eq "Created app with guid #{app_id}"
    expect(message.app_id).to eq app_id
    expect(message.source_type).to eq 'API'
    expect(message.message_type).to eq LogMessage::MessageType::OUT
  end
end
