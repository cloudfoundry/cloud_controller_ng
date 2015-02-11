require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe SecurityGroupEventRepository do
      let(:user) { User.make }
      let(:security_group) { SecurityGroup.make }
      let(:user_email) { 'email address' }

      subject(:security_group_event_repository) { SecurityGroupEventRepository.new }

      describe '#record_security_group_delete' do
        it 'records event correctly' do
          event = security_group_event_repository.record_security_group_delete_request(security_group, user, user_email)
          event.reload
          expect(event.type).to eq('audit.security_group.delete-request')
          expect(event.actee).to eq(security_group.guid)
          expect(event.actee_type).to eq('security_group')
          expect(event.actee_name).to eq(security_group.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.organization_guid).to eq('')
          expect(event.space_guid).to eq('')
        end
      end
    end
  end
end
