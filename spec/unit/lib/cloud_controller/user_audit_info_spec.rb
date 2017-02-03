require 'spec_helper'
require 'cloud_controller/user_audit_info'

module VCAP::CloudController
  RSpec.describe UserAuditInfo do
    let(:security_context) do
      class_double(SecurityContext,
        current_user_email: 'email',
        current_user_name:  'username',
        current_user:       User.new(guid: 'the-guid')
      )
    end

    describe '.from_context' do
      it 'creates from a Security Context' do
        info = described_class.from_context(security_context)
        expect(info.user_email).to eq('email')
        expect(info.user_name).to eq('username')
        expect(info.user_guid).to eq('the-guid')
      end
    end

    context 'defaults' do
      let(:security_context) do
        class_double(SecurityContext,
          current_user_email: nil,
          current_user_name:  nil,
          current_user:       User.new(guid: 'the-guid')
        )
      end

      describe '.from_context' do
        it 'defaults to empty strings from a nil-valued Security Context' do
          info = described_class.from_context(security_context)
          expect(info.user_email).to eq('')
          expect(info.user_name).to eq('')
          expect(info.user_guid).to eq('the-guid')
        end
      end
    end
  end
end
