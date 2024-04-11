require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteCreate do
    describe 'parallel creation of internal routes' do
      it 'retries until find_next_vip_offset does not return a conflicting number' do
        # Don't create events
        allow_any_instance_of(Repositories::RouteEventRepository).to receive(:record_route_create)

        threads = []
        10.times do
          threads << Thread.new do
            user_audit_info = UserAuditInfo.new(user_email: Sham.email, user_guid: Sham.guid)
            message = RouteCreateMessage.new(host: Sham.host)
            space = Space.make
            domain = SharedDomain.make(internal: true)

            route = nil
            expect do
              route = RouteCreate.new(user_audit_info).create(message:, space:, domain:)
            end.not_to raise_error
            expect(route).to exist

            # Wait until all routes are created...
            sleep(1)
            delete_db_entries(route, domain, space)
          end
        end
        threads.each(&:join)
      end
    end

    def delete_db_entries(route, domain, space)
      organization = space.organization
      quota_definition = organization.quota_definition

      [route, domain, space, organization, quota_definition].each(&:delete)
    end
  end
end
