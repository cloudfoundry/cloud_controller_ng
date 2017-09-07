require 'spec_helper'
require 'perm'

RSpec.describe 'Perm', type: :integration do
  let(:host) { ENV.fetch('PERM_RPC_HOST') { 'localhost:6283' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(host) }

  it 'can talk to Perm' do
    role = client.create_role('cc-perm-integration-test' + SecureRandom.uuid)

    expect(client.has_role?('some-actor', role.id)).to be false

    client.assign_role('some-actor', role.id)

    expect(client.has_role?('some-actor', role.id)).to be true
  end
end
