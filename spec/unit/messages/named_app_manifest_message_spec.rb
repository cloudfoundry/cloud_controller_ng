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
        let(:params) { { name: 'x' * 64, routes: routes } }

        context "when the 'routes' property is an empty array" do
          let(:routes) { [] }
          it 'is not valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to_not be_valid
            expect(message.errors.full_messages[0]).to match(/cannot exceed 63 characters when routes are not present/)
          end
        end

        context "when there's no 'routes' property" do
          let(:params) { { name: 'x' * 64 } }

          it 'is not valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to_not be_valid
            expect(message.errors.full_messages[0]).to match(/cannot exceed 63 characters when routes are not present/)
          end
        end

        context "when there's a valid route specified" do
          let(:routes) { [{ route: 'a.b.com' }] }

          it 'is valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to be_valid
          end
        end
      end

      context 'when the name contains special characters' do
        let(:params) { { name: '%%%', routes: routes } }

        context "when the 'routes' property is an empty array" do
          let(:routes) { [] }

          it 'is not valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to_not be_valid
            expect(message.errors.full_messages[0]).to match(/must contain only alphanumeric characters, "_", or "-"/)
          end
        end

        context "when there's no 'routes' property" do
          let(:params) { { name: '%%%' } }

          it 'is not valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to_not be_valid
            expect(message.errors.full_messages[0]).to match(/must contain only alphanumeric characters, "_", or "-"/)
          end
        end

        context "when there's a valid route specified" do
          let(:routes) { [{ route: 'a.b.com' }] }

          it 'is valid' do
            message = NamedAppManifestMessage.create_from_yml(params)

            expect(message).to be_valid
          end
        end
      end
    end
  end
end
