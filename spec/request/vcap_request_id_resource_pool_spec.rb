require 'spec_helper'

RSpec.describe 'making several resource_match requests when bits-service in enabled ' do
  let(:email) { 'potato@house.com' }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_name) { 'clarence' }
  let(:user_header) { headers_for(user, email: email, user_name: user_name) }

  it 'uses a new vcap-request-id on every instantiation of the Bits-Service ResourcePool' do
    TestConfig.override(bits_service: { enabled: true })

    ids = []

    expect(CloudController::DependencyLocator.instance).to receive(:bits_service_resource_pool).at_least(:once) {
      ids << VCAP::Request.current_id
      double('FakeResourcePool', matches: double('FakeMatch', body: ''))
    }
    3.times { put '/v2/resource_match', [{ fn: 'some-file', mode: '644', sha1: 'irrelevant', size: 1 }].to_json, user_header }
    expect(ids.uniq.length).to eq(3)
  end
end
