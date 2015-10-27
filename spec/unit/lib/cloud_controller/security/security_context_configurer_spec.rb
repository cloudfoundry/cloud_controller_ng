require 'spec_helper'
require 'cloud_controller/security/security_context_configurer'

module VCAP::CloudController
  module Security
    describe SecurityContextConfigurer do
      let(:configurer) { SecurityContextConfigurer.new(token_decoder) }
      let(:token_decoder) { double(VCAP::UaaTokenDecoder) }

      describe '#configure' do
        let(:auth_token) { 'auth-token' }
        let(:token_information) { { 'user_id' => user_guid } }
        let(:user_guid) { 'user-id-1' }

        before do
          allow(token_decoder).to receive(:decode_token).with(auth_token).and_return(token_information)
        end

        it 'initially clears the security context token' do
          SecurityContext.set('foo', 'bar')
          allow(token_decoder).to receive(:decode_token).with(auth_token).and_raise('BOGUS_TEST_ERROR')
          expect {
            configurer.configure(auth_token)
          }.to raise_error('BOGUS_TEST_ERROR')
          expect(SecurityContext.current_user).to be_nil
          expect(SecurityContext.token).to be_nil
        end

        it 'sets the security context token and the raw token' do
          configurer.configure(auth_token)
          expect(SecurityContext.token).to eq(token_information)
          expect(SecurityContext.auth_token).to eq(auth_token)
        end

        context 'when a user_id is present' do
          let(:token_information) { { 'user_id' => user_guid, 'client_id' => 'foobar' } }

          context 'when the specified user already exists' do
            let!(:user) { User.make(guid: user_guid) }

            it 'sets that user on security context' do
              configurer.configure(auth_token)
              expect(SecurityContext.current_user).to eq(user)
            end
          end

          context 'when the specified user does not exist' do
            it 'creates an active user with that id' do
              expect {
                configurer.configure(auth_token)
              }.to change { User.count }.by(1)
              expect(SecurityContext.current_user.guid).to eq(user_guid)
              expect(SecurityContext.current_user).to be_active
            end
          end

          context 'when the specified user is created after verifying it does not exist' do
            it 'finds the created user' do
              User.make(guid: user_guid)
              allow(User).to receive(:find) do
                allow(User).to receive(:find).and_call_original
                nil
              end
              configurer.configure(auth_token)
              expect(SecurityContext.current_user.guid).to eq(user_guid)
            end
          end
        end

        context 'when only a client_id is present' do
          let(:token_information) { { 'client_id' => user_guid } }
          let!(:user) { User.make(guid: user_guid) }

          it 'uses the client_id to set the user_id' do
            configurer.configure(auth_token)
            expect(SecurityContext.current_user).to eq(user)
          end
        end

        context 'when neither a user_id nor a client_id is present' do
          let(:token_information) { {} }

          it 'sets the SecurityContext user and token to nil' do
            configurer.configure(auth_token)
            expect(SecurityContext.current_user).to be_nil
            expect(SecurityContext.token).to be_nil
          end
        end

        context 'when the auth_token is invalid or expired' do
          before do
            allow(token_decoder).to receive(:decode_token).with(auth_token).and_raise(VCAP::UaaTokenDecoder::BadToken)
            SecurityContext.set('value', 'another')
          end

          it 'sets the SecurityContext user and token to error values' do
            expect { configurer.configure(auth_token) }.not_to raise_error
            expect(SecurityContext.current_user).to be_nil
            expect(SecurityContext.token).to eq(:invalid_token)
            expect(SecurityContext.auth_token).to eq(auth_token)
          end
        end

        context 'when the decoded token is nil' do
          before do
            allow(token_decoder).to receive(:decode_token).with(auth_token).and_return(nil)
            SecurityContext.set('value', 'another')
          end

          it 'clears the SecurityContext and does not raise' do
            expect { configurer.configure(auth_token) }.not_to raise_error
            expect(SecurityContext.current_user).to be_nil
            expect(SecurityContext.token).to be_nil
            expect(SecurityContext.auth_token).to eq(auth_token)
          end
        end
      end
    end
  end
end
