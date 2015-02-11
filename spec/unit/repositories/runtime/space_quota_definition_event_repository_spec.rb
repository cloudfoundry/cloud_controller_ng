require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe SpaceQuotaDefinitionEventRepository do
      let(:user) { User.make }
      let(:space_quota_definition) { SpaceQuotaDefinition.make }
      let(:user_email) { 'email address' }

      subject(:space_quota_definition_event_repository) { SpaceQuotaDefinitionEventRepository.new }

      describe '#record_space_delete' do
        it 'records event correctly' do
          event = space_quota_definition_event_repository.record_space_quota_definition_delete_request(space_quota_definition, user, user_email)
          event.reload
          expect(event.space).to be_nil
          expect(event.type).to eq('audit.space_quota_definition.delete-request')
          expect(event.actee).to eq(space_quota_definition.guid)
          expect(event.actee_type).to eq('space_quota_definition')
          expect(event.actee_name).to eq(space_quota_definition.name)
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq(space_quota_definition.organization.guid)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
        end
      end
    end
  end
end
