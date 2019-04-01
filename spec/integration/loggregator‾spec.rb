require 'spec_helper'
require 'securerandom'
require 'tempfile'

RSpec.describe 'Cloud controller Loggregator Integration', type: :integration do
  before(:all) do
    @loggregator_server = FakeLoggregatorServer.new(12345)
    @loggregator_server.start

    @authed_headers = {
        'Authorization' => "bearer #{admin_token}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
    }

    base_cc_config_file = 'config/cloud_controller.yml'
    port_8181_overrides = 'spec/fixtures/config/port_8181_config.yml'
    config = VCAP::CloudController::YAMLConfig.safe_load_file(base_cc_config_file).deep_merge(
      VCAP::CloudController::YAMLConfig.safe_load_file(port_8181_overrides)
    )

    @cc_config_file = Tempfile.new('cc_config.yml')
    @cc_config_file.write(YAML.dump(config))
    @cc_config_file.close

    start_cc(debug: false, config: @cc_config_file.path)

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
    @cc_config_file.unlink
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
