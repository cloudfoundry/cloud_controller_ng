require 'spec_helper'
require 'messages/role_create_message'
require 'models/helpers/role_types'

module VCAP::CloudController
  RSpec.describe RoleCreateMessage do
    subject { RoleCreateMessage }
    let(:user_guid) { 'user-guid' }
    let(:space_guid) { 'space-guid' }
    let(:organization_guid) { 'organization-guid' }
    let(:type) { 'space_auditor' }
    let(:space_params) do
      {
        type: type,
        relationships: {
          user: {
            data: { guid: user_guid }
          },
          space: {
            data: { guid: space_guid }
          },
        }
      }
    end
    let(:organization_params) do
      {
        type: type,
        relationships: {
          user: {
            data: { guid: user_guid }
          },
          organization: {
            data: { guid: organization_guid }
          },
        }
      }
    end

    context 'when no params are given' do
      let(:params) {}
      it 'is not valid' do
        message = subject.new(params)
        expect(message).to be_invalid
        expect(message.errors[:user_guid]).to include('must be a string', 'must be between 1 and 200 characters')
        expect(message.errors[:relationships]).to include('Role must be associated with either a space or an organization.')
      end
    end

    context 'when unexpected keys are requested' do
      let(:params) do
        {
          unexpected: 'meow',
          type: type,
          relationships: {
            user: { guid: user_guid },
            space: { guid: space_guid }
          }
        }
      end

      it 'is not valid' do
        message = subject.new(params)
        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end
    end

    context 'type' do
      context 'when the type is invalid' do
        let(:type) { 'something-else' }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:type]).to include("must be one of the allowed types #{VCAP::CloudController::RoleTypes::ALL_ROLES}")
        end
      end
    end

    context 'user_guid' do
      context 'when not a string' do
        let(:user_guid) { 5 }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:user_guid]).to include('must be a string')
        end
      end

      context 'when it is too short' do
        let(:user_guid) { '' }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:user_guid]).to include 'must be between 1 and 200 characters'
        end
      end

      context 'when it is too long' do
        let(:user_guid) { 'B' * (200 + 1) }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:user_guid]).to include 'must be between 1 and 200 characters'
        end
      end
    end

    context('space_guid') do
      context 'and type' do
        VCAP::CloudController::RoleTypes::SPACE_ROLES.each do |space_type|
          context "when the type is #{space_type}" do
            let(:type) { space_type }

            it 'is valid' do
              message = subject.new(space_params)
              expect(message).to be_valid
            end
          end
        end

        VCAP::CloudController::RoleTypes::ORGANIZATION_ROLES.each do |org_type|
          context "when the type is #{org_type}" do
            let(:type) { org_type }

            it 'is valid' do
              message = subject.new(space_params)
              expect(message).not_to be_valid
              expect(message.errors[:type]).to include("Role with type '#{org_type}' cannot be associated with a space.")
            end
          end
        end
      end

      context 'when not a string' do
        let(:space_guid) { 5 }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).not_to be_valid
          expect(message.errors[:space_guid]).to include('must be a string')
        end
      end

      context 'when it is too short' do
        let(:space_guid) { '' }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:space_guid]).to include 'must be between 1 and 200 characters'
        end
      end

      context 'when it is too long' do
        let(:space_guid) { 'B' * (200 + 1) }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:space_guid]).to include 'must be between 1 and 200 characters'
        end
      end
    end

    context 'organization_guid' do
      context 'and type' do
        VCAP::CloudController::RoleTypes::SPACE_ROLES.each do |space_type|
          context "when the type is #{space_type}" do
            let(:type) { space_type }

            it 'is valid' do
              message = subject.new(organization_params)
              expect(message).not_to be_valid
              expect(message.errors[:type]).to include("Role with type '#{space_type}' cannot be associated with an organization.")
            end
          end
        end

        VCAP::CloudController::RoleTypes::ORGANIZATION_ROLES.each do |org_type|
          context "when the type is #{org_type}" do
            let(:type) { org_type }

            it 'is valid' do
              message = subject.new(organization_params)
              expect(message).to be_valid
            end
          end
        end
      end
      context 'when not a string' do
        let(:organization_guid) { 5 }

        it 'is not valid' do
          message = subject.new(organization_params)
          expect(message).not_to be_valid
          expect(message.errors[:organization_guid]).to include('must be a string')
        end
      end

      context 'when it is too short' do
        let(:organization_guid) { '' }

        it 'is not valid' do
          message = subject.new(organization_params)
          expect(message).to be_invalid
          expect(message.errors[:organization_guid]).to include 'must be between 1 and 200 characters'
        end
      end

      context 'when it is too long' do
        let(:organization_guid) { 'B' * (200 + 1) }

        it 'is not valid' do
          message = subject.new(organization_params)
          expect(message).to be_invalid
          expect(message.errors[:organization_guid]).to include 'must be between 1 and 200 characters'
        end
      end
    end

    context 'organization_guid and space guid are both provided' do
      let(:organization_and_space_params) do
        {
          type: type,
          relationships: {
            user: {
              data: { guid: user_guid }
            },
            space: {
              data: { guid: space_guid }
            },
            organization: {
              data: { guid: organization_guid }
            },
          }
        }
      end

      it 'is not valid' do
        message = subject.new(organization_and_space_params)
        expect(message).not_to be_valid
        expect(message.errors[:relationships]).to include('Role cannot be associated with both an organization and a space.')
      end
    end
  end
end
