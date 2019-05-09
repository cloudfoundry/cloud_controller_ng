require 'spec_helper'
require 'actions/route_create'
require 'messages/route_create_message'

module VCAP::CloudController
  RSpec.describe RouteCreate do
    subject { RouteCreate.new }

    describe '#create' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:org) { space.organization }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

      context 'when successful' do
        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
        end

        it 'creates a route' do
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to change { Route.count }.by(1)

          route = Route.last
          expect(route.space.guid).to eq space.guid
          expect(route.domain.guid).to eq domain.guid
        end
      end

      context 'when the domain has an owning org that is different from the space\'s parent org' do
        let(:other_org) { VCAP::CloudController::Organization.make }
        let(:inaccessible_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: other_org) }

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: inaccessible_domain.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space, domain: inaccessible_domain)
          }.to raise_error(RouteCreate::Error, "Invalid domain. Domain '#{inaccessible_domain.name}' is not available in organization '#{space.organization.name}'.")
        end
      end

      context 'when the domain already has a route' do
        let!(:existing_route) { VCAP::CloudController::Route.make(host: '', space: space, domain: domain) }

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Route already exists for domain '#{domain.name}'.")
        end
      end

      context 'when the space quota for routes is maxed out' do
        let!(:space_quota_definition) { SpaceQuotaDefinition.make(total_routes: 0, organization: org) }
        let!(:space_with_quota) do
          Space.make(space_quota_definition: space_quota_definition,
            organization: org)
        end

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space_with_quota.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space_with_quota, domain: domain)
          }.to raise_error(RouteCreate::Error, "Routes quota exceeded for space '#{space_with_quota.name}'.")
        end
      end

      context 'when the org quota for routes is maxed out' do
        let!(:org_quota_definition) { QuotaDefinition.make(total_routes: 0, total_reserved_route_ports: 0) }
        let!(:org_with_quota) { Organization.make(quota_definition: org_quota_definition) }
        let!(:space_in_org_with_quota) do
          Space.make(organization: org_with_quota)
        end
        let(:domain_in_org_with_quota) { Domain.make(owning_organization: org_with_quota) }

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space_in_org_with_quota.guid }
              },
              domain: {
                data: { guid: domain_in_org_with_quota.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space_in_org_with_quota, domain: domain_in_org_with_quota)
          }.to raise_error(RouteCreate::Error, "Routes quota exceeded for organization '#{org_with_quota.name}'.")
        end
      end
    end
  end
end
