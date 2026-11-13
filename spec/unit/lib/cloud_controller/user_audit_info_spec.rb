require 'spec_helper'
require 'cloud_controller/user_audit_info'

module VCAP::CloudController
  RSpec.describe UserAuditInfo do
    let(:security_context) do
      class_double(SecurityContext,
                   current_user_email: 'email',
                   current_user_name: 'username',
                   current_user: User.new(guid: 'the-guid'))
    end

    describe '.from_context' do
      it 'creates from a Security Context' do
        info = UserAuditInfo.from_context(security_context)
        expect(info.user_email).to eq('email')
        expect(info.user_name).to eq('username')
        expect(info.user_guid).to eq('the-guid')
      end
    end

    describe '#hash_for_logs' do
      it 'returns only the non-sensitive identity fields' do
        info = UserAuditInfo.new(user_email: 'e', user_name: 'n', user_guid: 'g')
        expect(info.hash_for_logs).to eq(user_guid: 'g', user_email: 'e', user_name: 'n')
      end
    end

    context 'defaults' do
      let(:security_context) do
        class_double(SecurityContext,
                     current_user_email: nil,
                     current_user_name: nil,
                     current_user: User.new(guid: 'the-guid'))
      end

      describe '.from_context' do
        it 'defaults to empty strings from a nil-valued Security Context' do
          info = UserAuditInfo.from_context(security_context)
          expect(info.user_email).to eq('')
          expect(info.user_name).to eq('')
          expect(info.user_guid).to eq('the-guid')
        end
      end
    end
  end
end
