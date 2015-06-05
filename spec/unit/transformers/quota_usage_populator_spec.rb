require 'spec_helper'

module VCAP::CloudController
  describe QuotaUsagePopulator do
    let(:quotaUsage_populator) { QuotaUsagePopulator.new }
    let(:quota_definition) { QuotaDefinition.make }
    let(:space_quota_definition) { SpaceQuotaDefinition.make(organization: org) }
    let(:quota_definition_guid) { quota_definition.guid }
    let(:org) { Organization.make_unsaved(quota_definition: quota_definition, quota_definition_guid: quota_definition_guid) }
    let(:space) { Space.make(organization: org, space_quota_definition: space_quota_definition) }
    let(:domain) { PrivateDomain.make(owning_organization: org) }
    let(:route) { Route.make(domain: domain, space: space) }
    let(:route1) { Route.make(domain: domain, space: space) }
    let(:service_instance) { ManagedServiceInstance.make(space: space) }
    let(:app) { AppFactory.make(space: space, instances: 1, memory: 500, state: 'STARTED') }

    before do
      org.save
      org.add_space(space)
      app.add_route(route)
      app.add_route(route1)
      space.add_service_instance(service_instance)
      space.add_app(app)
    end

    describe 'transform' do
      it 'populates organization quota usage' do
        quotaUsage_populator.transform(quota_definition, organization_id: org.id)
        expect(quota_definition.org_usage).to eq({ 'routes' => 2, 'services' => 1, 'memory' => 500 })
      end

      it 'populates space quota usage' do
        quotaUsage_populator.transform(space.space_quota_definition, space_id: space.id)
        expect(space.space_quota_definition.space_usage).to eq({ 'routes' => 2, 'services' => 1, 'memory' => 500 })
      end
    end
  end
end
