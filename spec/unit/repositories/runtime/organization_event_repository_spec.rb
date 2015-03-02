require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe OrganizationEventRepository do
      let(:user) { User.make }
      let(:organization) { Organization.make }
      let(:user_email) { 'email address' }

      subject(:organization_event_repository) { OrganizationEventRepository.new }

      describe '#record_organization_delete' do
        it 'records event correctly' do
          event = organization_event_repository.record_organization_delete_request(organization, user, user_email)
          event.reload
          expect(event.type).to eq('audit.organization.delete-request')
          expect(event.actee).to eq(organization.guid)
          expect(event.actee_type).to eq('organization')
          expect(event.actee_name).to eq(organization.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.space_guid).to eq('')
        end
      end
    end
  end
end
