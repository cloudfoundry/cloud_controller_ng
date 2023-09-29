require 'spec_helper'
require 'cloud_controller/security/security_context_configurer'

module VCAP::CloudController
  module Security
    RSpec.describe SecurityContextConfigurer do
      let(:configurer) { SecurityContextConfigurer.new(token_decoder) }
      let(:token_decoder) { double(VCAP::CloudController::UaaTokenDecoder) }

      describe '#configure' do
        let(:auth_token) { 'auth-token' }
        let(:token_information) { { 'user_id' => user_id } }
        let(:user_id) { 'user-id-1' }

        before do
          allow(token_decoder).to receive(:decode_token).with(auth_token).and_return(token_information)
        end

        it 'initially clears the security context token' do
          SecurityContext.set('foo', 'bar', 'baz')

          # Fail early in the #configure so that we do not set new values on the token
          allow(token_decoder).to receive(:decode_token).with(auth_token).and_raise('BOGUS_TEST_ERROR')
          expect do
            configurer.configure(auth_token)
          end.to raise_error('BOGUS_TEST_ERROR')

          expect(SecurityContext.current_user).to be_nil
          expect(SecurityContext.token).to be_nil
          expect(SecurityContext.auth_token).to be_nil
        end

        it 'sets the security context token and the raw token' do
          configurer.configure(auth_token)
          expect(SecurityContext.token).to eq(token_information)
          expect(SecurityContext.auth_token).to eq(auth_token)
        end

        context 'when a user_id is present' do
          let(:token_information) { { 'user_id' => user_id, 'client_id' => 'foobar' } }

          context 'when the specified user already exists (without information about client-ness)' do
            let!(:user) { User.make(guid: user_id, is_oauth_client: nil) }

            it 'sets that user on security context' do
              configurer.configure(auth_token)
              expect(SecurityContext.current_user.id).to eq(user.id)
              expect(SecurityContext.current_user.guid).to eq(user.guid)
              expect(SecurityContext.current_user).not_to be_is_oauth_client
              expect(SecurityContext.current_user.is_oauth_client?).not_to be_nil
            end
          end

          context 'when the specified user already exists as a client' do
            let!(:user) { User.make(guid: user_id, is_oauth_client: true) }

            it 'sets invalid token' do
              configurer.configure(auth_token)
              expect(SecurityContext.current_user).to be_nil
              expect(SecurityContext.token).to eq(:invalid_token)
              expect(SecurityContext.auth_token).to eq(auth_token)
            end
          end

          context 'when the specified user does not exist' do
            it 'creates an active user with that id' do
              expect do
                configurer.configure(auth_token)
              end.to change(User, :count).by(1)
              expect(SecurityContext.current_user.guid).to eq(user_id)
              expect(SecurityContext.current_user).to be_active
              expect(SecurityContext.current_user).not_to be_is_oauth_client
              expect(SecurityContext.current_user.is_oauth_client?).not_to be_nil
            end
          end

          context 'when the specified user is created after verifying it does not exist' do
            it 'finds the created user' do
              User.make(guid: user_id)
              allow(User).to receive(:find) do
                allow(User).to receive(:find).and_call_original
                nil
              end
              configurer.configure(auth_token)
              expect(SecurityContext.current_user.guid).to eq(user_id)
            end
          end
        end

        context 'when only a client_id is present' do
          let(:token_information) { { 'client_id' => user_id } }
          let!(:user) { User.make(guid: user_id) }
          let(:uaa_client) { double(UaaClient) }

          before do
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).
              and_return(uaa_client)
          end

          it 'records that the user is a client' do
            configurer.configure(auth_token)
            expect(SecurityContext.current_user).to be_is_oauth_client
          end

          it 'uses the client_id to set the user_id' do
            configurer.configure(auth_token)
            expect(SecurityContext.current_user.guid).to eq(user.guid)
            expect(SecurityContext.current_user.guid).to eq(token_information['client_id'])
          end

          it 'doesnt needlessly ask the uaa client for users' do
            expect(uaa_client).not_to receive(:usernames_for_ids)
            configurer.configure(auth_token)
          end

          context 'when the client_id is a guid' do
            let(:user_id) { 'ab0a3e8f-9d53-426e-b73d-e035edbc0c03' }

            context 'when the client_id is also a valid uaa user_id' do
              before do
                expect(uaa_client).to receive(:usernames_for_ids).
                  and_return({ user_id => 'org-manager' })
              end

              it 'sets invalid token' do
                configurer.configure(auth_token)
                expect(SecurityContext.current_user).to be_nil
                expect(SecurityContext.token).to eq(:invalid_token)
                expect(SecurityContext.auth_token).to eq(auth_token)
              end
            end

            context 'when the client_id is not also a uaa user_id' do
              before do
                expect(uaa_client).to receive(:usernames_for_ids).
                  and_return({})
              end

              it 'uses the client_id to set the user_id' do
                configurer.configure(auth_token)
                expect(SecurityContext.current_user.guid).to eq(user.guid)
              end
            end

            context 'theres a user with the same id' do
              let!(:user) { User.make(guid: user_id, is_oauth_client: false) }

              before do
                expect(uaa_client).not_to receive(:usernames_for_ids)
              end

              it 'sets invalid token without talking to uaa' do
                configurer.configure(auth_token)
                expect(SecurityContext.current_user).to be_nil
                expect(SecurityContext.token).to eq(:invalid_token)
                expect(SecurityContext.auth_token).to eq(auth_token)
              end
            end
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
            allow(token_decoder).to receive(:decode_token).with(auth_token).and_raise(VCAP::CloudController::UaaTokenDecoder::BadToken)
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
