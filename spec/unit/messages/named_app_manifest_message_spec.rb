require 'spec_helper'
require 'messages/named_app_manifest_message'

module VCAP::CloudController
  RSpec.describe NamedAppManifestMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { name: 'hawaiian', instances: 3, memory: '2G' } }

        it 'is valid' do
          message = NamedAppManifestMessage.create_from_yml(params)

          expect(message).to be_valid
        end
      end

      context 'when name is not specified' do
        let(:params) { { instances: 3, memory: '2G' } }

        it 'is not valid' do
          message = NamedAppManifestMessage.create_from_yml(params)

          expect(message).to_not be_valid
          expect(message.errors.full_messages[0]).to match(/^Name must not be empty/)
        end
      end

      context 'when the name is too long' do
        let(:params) { { name: 'x' * 64, 'default-route': default_route } }

        context 'when default-route is true' do
          let(:default_route) { true }

          it 'is not valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to_not be_valid
            expect(message.errors.full_messages[0]).to match(/Host cannot exceed 63 characters/)
          end
        end

        context 'when default-route is false' do
          let(:default_route) { false }

          it 'is valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to be_valid
          end
        end

        context 'when default-route is not set' do
          let(:default_route) { nil }

          it 'is valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to be_valid
          end
        end
      end

      context 'when the name contains special characters' do
        let(:params) { { name: '%%%', 'default-route': default_route } }

        context 'when default-route is true' do
          let(:default_route) { true }

          it 'is not valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to_not be_valid
            expect(message.errors.full_messages[0]).to match(/Host must be either "\*" or contain only alphanumeric characters, "_", or "-"/)
          end
        end

        context 'when default-route is false' do
          let(:default_route) { false }

          it 'is valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to be_valid
          end
        end

        context 'when default-route is not set' do
          let(:default_route) { nil }

          it 'is valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to be_valid
          end
        end
      end
    end
  end
end
