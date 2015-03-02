require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe ServiceAuthTokenEventRepository do
      let(:user) { User.make }
      let(:service_auth_token) { ServiceAuthToken.make }
      let(:user_email) { 'email address' }

      subject(:service_auth_token_event_repository) { ServiceAuthTokenEventRepository.new }

      describe '#record_service_auth_token_delete' do
        it 'records event correctly' do
          event = service_auth_token_event_repository.record_service_auth_token_delete_request(service_auth_token, user, user_email)
          event.reload
          expect(event.type).to eq('audit.service_auth_token.delete-request')
          expect(event.actee).to eq(service_auth_token.guid)
          expect(event.actee_type).to eq('service_auth_token')
          expect(event.actee_name).to eq(service_auth_token.label)
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
