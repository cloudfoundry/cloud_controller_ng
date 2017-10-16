require 'spec_helper'

module VCAP
  module CloudController
    module Repositories
      RSpec.describe ServiceInstanceShareEventRepository do
        let(:service_instance) { ServiceInstance.make }
        let(:user_guid) { 'user-guid' }
        let(:user_email) { 'user-email' }
        let(:user_name) { 'user-name' }
        let(:user_audit_info) { UserAuditInfo.new(user_guid: user_guid, user_name: user_name, user_email: user_email) }
        let(:target_space_guids) { ['space-guid', 'another-guid'] }

        describe '#record_share_event' do
          it 'records the event correctly' do
            event = ServiceInstanceShareEventRepository.record_share_event(service_instance, target_space_guids, user_audit_info)

            expect(event.type).to eq('audit.service_instance.share')
            expect(event.actor).to eq(user_guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(user_email)
            expect(event.actor_username).to eq(user_name)
            expect(event.actee).to eq(service_instance.guid)
            expect(event.actee_type).to eq('service_instance')
            expect(event.actee_name).to eq(service_instance.name)
            expect(event.metadata[:target_space_guids]).to eq(['space-guid', 'another-guid'])
            expect(event.space_guid).to eq(service_instance.space.guid)
            expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          end
        end

        describe '#record_unshare_event' do
          it 'records the event correctly' do
            event = ServiceInstanceShareEventRepository.record_unshare_event(service_instance, target_space_guids[0], user_audit_info)

            expect(event.type).to eq('audit.service_instance.unshare')
            expect(event.actor).to eq(user_guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(user_email)
            expect(event.actor_username).to eq(user_name)
            expect(event.actee).to eq(service_instance.guid)
            expect(event.actee_type).to eq('service_instance')
            expect(event.actee_name).to eq(service_instance.name)
            expect(event.metadata[:target_space_guid]).to eq('space-guid')
            expect(event.space_guid).to eq(service_instance.space.guid)
            expect(event.organization_guid).to eq(service_instance.space.organization.guid)
          end
        end
      end
    end
  end
end
