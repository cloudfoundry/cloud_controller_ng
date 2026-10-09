require 'spec_helper'

RSpec.describe 'Explicit service account resource roles' do
  let(:space) { create(:space) }
  let(:admin) { create(:user) }
  let(:account) { VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space) }
  let(:clients) { instance_double(CF::UAA::Scim) }
  let(:principal) { VCAP::CloudController::User.first(guid: account.client_id) }

  before do
    allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
    allow(clients).to receive(:add)
    VCAP::CloudController::ServiceAccountProvision.new(clients, identity_ca: 'identity-ca').provision(account)
    lookup = instance_double(VCAP::CloudController::UaaClient, usernames_for_ids: {})
    expect(lookup).not_to receive(:usernames_for_ids).with([principal.guid])
    allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(lookup)
  end

  def grant(type, resource, guid)
    post '/v3/roles', {
      type: type,
      relationships: { user: { data: { guid: principal.guid } }, resource => { data: { guid: guid } } }
    }.to_json, admin_headers_for(admin)
  end

  it 'requires explicit organization membership and then a space role before account tokens can write apps' do
    grant('space_developer', :space, space.guid)
    expect(last_response.status).to eq(422)
    grant('organization_user', :organization, space.organization.guid)
    expect(last_response.status).to eq(201)

    app_body = { name: 'account-created', relationships: { space: { data: { guid: space.guid } } } }
    post '/v3/apps', app_body.to_json, headers_for(principal, client: true)
    expect(last_response.status).to eq(422)

    grant('space_developer', :space, space.guid)
    expect(last_response.status).to eq(201)
    post '/v3/apps', app_body.to_json, headers_for(principal, client: true)
    expect(last_response.status).to eq(201)

    post '/v3/service_accounts', { name: 'privilege-escalation', relationships: { space: { data: { guid: space.guid } } } }.to_json, headers_for(principal, client: true)
    expect(last_response.status).to eq(403)
  end

  it 'keeps account tokens denied in unrelated spaces after an explicit role grant' do
    grant('organization_user', :organization, space.organization.guid)
    grant('space_developer', :space, space.guid)
    other = create(:space, organization: space.organization)
    post '/v3/apps', { name: 'unauthorized', relationships: { space: { data: { guid: other.guid } } } }.to_json, headers_for(principal, client: true)
    expect(last_response.status).to eq(422)
  end
end
