require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe QuotaDefinitionEventRepository do
      let(:user) { User.make }
      let(:quota_definition) { QuotaDefinition.make }
      let(:user_email) { 'email address' }

      subject(:quota_definition_event_repository) { QuotaDefinitionEventRepository.new }

      describe '#record_quota_definition_delete' do
        it 'records event correctly' do
          event = quota_definition_event_repository.record_quota_definition_delete_request(quota_definition, user, user_email)
          event.reload
          expect(event.type).to eq('audit.quota_definition.delete-request')
          expect(event.actee).to eq(quota_definition.guid)
          expect(event.actee_type).to eq('quota_definition')
          expect(event.actee_name).to eq(quota_definition.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.space_guid).to eq('')
        end
      end
    end
  end
end
