require 'spec_helper'
require 'active_model'
require 'messages/mixins/authentication_message_mixin'

module VCAP::CloudController
  RSpec.describe AuthenticationMessageMixin do
    describe '#audit_hash' do
      let(:valid_body) do
        {
          authentication: {
            type: 'basic',
            credentials: {
              username: 'user',
              password: 'pass',
            }
          }
        }
      end

      it 'redacts the password' do
        message = AuthenticationMessageMixinTest.new(valid_body)

        expect(message.audit_hash).to eq({
          authentication: {
            type: 'basic',
            credentials: {
              username: 'user',
              password: '[PRIVATE DATA HIDDEN]',
            }
          },
        }.with_indifferent_access)
      end
    end
  end

  class AuthenticationMessageMixinTest < BaseMessage
    register_allowed_keys [:authentication]
    include AuthenticationMessageMixin
  end
end
