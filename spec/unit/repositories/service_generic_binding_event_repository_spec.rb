require 'spec_helper'
require 'repositories/service_generic_binding_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe ServiceGenericBindingEventRepository do
      let(:user_guid) { 'user-guid' }
      let(:user_email) { 'some-email' }
      let(:user_name) { 'some-username' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid:, user_name:, user_email:) }
      let(:service_binding) { create(:service_binding, name: 'some-binding-name') }
      let(:repository) { described_class.new(described_class::SERVICE_APP_CREDENTIAL_BINDING) }

      describe '#record_start_create' do
        it 'censors metadata.request.parameters' do
          request = { 'big' => 'data', 'parameters' => { 'secret' => 'value' } }

          event = repository.record_start_create(service_binding, user_audit_info, request)

          expect(event.metadata[:request]).to eq(
            {
              'big' => 'data',
              'parameters' => '[PRIVATE DATA HIDDEN]'
            }
          )
        end
      end

      describe '#record_create' do
        it 'censors metadata.request.parameters' do
          request = { 'big' => 'data', parameters: { 'secret' => 'value' } }

          event = repository.record_create(service_binding, user_audit_info, request)

          expect(event.metadata[:request]).to eq(
            {
              'big' => 'data',
              'parameters' => '[PRIVATE DATA HIDDEN]'
            }
          )
        end
      end

      describe '#record_update' do
        it 'censors metadata.request.parameters' do
          request = { 'big' => 'data', 'parameters' => { 'secret' => 'value' } }

          event = repository.record_update(service_binding, user_audit_info, request)

          expect(event.metadata[:request]).to eq(
            {
              'big' => 'data',
              'parameters' => '[PRIVATE DATA HIDDEN]'
            }
          )
        end
      end
    end
  end
end
