require 'spec_helper'

module VCAP::CloudController
  module V2
    RSpec.describe RouteCreate do
      let(:access_validator) { instance_double(RoutesController) }
      let(:logger) { instance_double(Steno::Logger) }
      let(:route_create) { RouteCreate.new(access_validator: access_validator, logger: logger) }
      let(:host) { 'some-host' }
      let(:space_quota_definition) { SpaceQuotaDefinition.make }
      let(:space) do
        Space.make(space_quota_definition: space_quota_definition,
          organization: space_quota_definition.organization)
      end
      let(:domain) { SharedDomain.make }
      let(:path) { '/some-path' }
      let(:route_hash) do
        {
          host: host,
          domain_guid: domain.guid,
          space_guid: space.guid,
          path: path
        }
      end

      describe '#create_route' do
        before do
          allow(access_validator).to receive(:validate_access)
        end

        context 'when access validation fails' do
          before do
            allow(access_validator).to receive(:validate_access).and_raise('some-exception')
          end

          it 'should not create a route in the db' do
            expect {
              begin
                route_create.create_route(route_hash: route_hash)
              rescue
              end
            }.not_to change { Route.count }
          end

          it 'should bubble up the exception' do
            expect { route_create.create_route(route_hash: route_hash) }.to raise_error('some-exception')
          end
        end
      end
    end
  end
end
