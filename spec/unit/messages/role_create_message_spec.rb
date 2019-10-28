require 'spec_helper'
require 'messages/role_create_message'
require 'models/helpers/role_types'

module VCAP::CloudController
  RSpec.describe RoleCreateMessage do
    subject { RoleCreateMessage }

    let(:user_guid) { 'user-guid' }
    let(:user_name) { 'user-name' }
    let(:user_origin) { 'user-origin' }
    let(:space_guid) { 'space-guid' }
    let(:space_type) { 'space_auditor' }
    let(:org_guid) { 'organization-guid' }
    let(:org_type) { 'organization_auditor' }

    let(:user_data) do
      {
        guid: user_guid
      }
    end

    let(:space_data) do
      {
        guid: space_guid
      }
    end

    let(:org_data) do
      {
        guid: org_guid
      }
    end

    let(:space_params) do
      {
        type: type,
        relationships: {
          user: {
            data: user_data
          },
          space: {
            data: space_data
          },
        }
      }
    end

    let(:org_params) do
      {
        type: type,
        relationships: {
          user: {
            data: user_data
          },
          organization: {
            data: org_data
          },
        }
      }
    end

    context 'when creating a space role by user guid' do
      let(:type) { space_type }

      it 'is valid' do
        message = subject.new(space_params)
        expect(message).to be_valid
      end
    end

    context 'when creating an org role by user guid' do
      let(:type) { org_type }

      it 'is valid' do
        message = subject.new(org_params)
        expect(message).to be_valid
      end
    end

    context 'when creating a space role by user name' do
      let(:type) { space_type }
      let(:user_data) { { name: user_name } }

      it 'is valid' do
        message = subject.new(space_params)
        expect(message).to be_valid
      end
    end

    context 'when creating an org role by user name' do
      let(:type) { org_type }
      let(:user_data) { { name: user_name } }

      it 'is valid' do
        message = subject.new(org_params)
        expect(message).to be_valid
      end
    end

    context 'when creating a space role by user name and origin' do
      let(:type) { space_type }
      let(:user_data) { { name: user_name, origin: user_origin } }

      it 'is valid' do
        message = subject.new(space_params)
        expect(message).to be_valid
      end
    end

    context 'when creating an org role by user name and origin' do
      let(:type) { org_type }
      let(:user_data) { { name: user_name, origin: user_origin } }

      it 'is valid' do
        message = subject.new(org_params)
        expect(message).to be_valid
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

      context 'for space roles' do
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

            it 'is not valid' do
              message = subject.new(space_params)
              expect(message).not_to be_valid
              expect(message.errors[:base]).to include("Role with type '#{org_type}' cannot be associated with a space.")
            end
          end
        end
      end

      context 'for org roles' do
        VCAP::CloudController::RoleTypes::ORGANIZATION_ROLES.each do |org_type|
          context "when the type is #{org_type}" do
            let(:type) { org_type }

            it 'is valid' do
              message = subject.new(org_params)
              expect(message).to be_valid
            end
          end
        end

        VCAP::CloudController::RoleTypes::SPACE_ROLES.each do |space_type|
          context "when the type is #{space_type}" do
            let(:type) { space_type }

            it 'is not valid' do
              message = subject.new(org_params)
              expect(message).not_to be_valid
              expect(message.errors[:base]).to include("Role with type '#{space_type}' cannot be associated with an organization.")
            end
          end
        end
      end
    end

    context 'when no params are given' do
      let(:params) {}

      it 'is not valid' do
        message = subject.new(params)
        expect(message).to be_invalid
        expect(message.errors.full_messages).to include('Role must be associated with either a space or an organization.')
        expect(message.errors.full_messages).to include(
          'Type must be one of the allowed types ["organization_auditor", "organization_manager", ' \
          '"organization_billing_manager", "organization_user", "space_auditor", "space_manager", "space_developer"]'
        )
      end
    end

    context 'when unexpected keys are requested' do
      let(:params) do
        {
          unexpected: 'meow',
          type: space_type,
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

    context 'user_guid/user_name/user_origin' do
      let(:type) { space_type }

      context 'when user_guid is not a string' do
        let(:user_guid) { 5 }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include('User guid must be a string')
        end
      end

      context 'when user_guid is missing' do
        let(:user_guid) { nil }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include('User guid must be a string')
        end
      end

      context 'when user_name is not a string' do
        let(:user_data) do
          {
            name: 47
          }
        end

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include('User name must be a string')
        end
      end

      context 'when user_origin is not a string' do
        let(:user_data) do
          {
            name: user_name,
            origin: 47
          }
        end

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include('User origin must be a string')
        end
      end

      context 'when user_guid is combined with user_name' do
        let(:user_data) do
          {
            name: user_name,
            guid: user_guid
          }
        end

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:user_name]).to include('cannot be specified when identifying user by guid')
        end
      end

      context 'when user_guid is combined with user_origin' do
        let(:user_data) do
          {
            guid: user_guid,
            origin: user_origin
          }
        end

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:user_origin]).to include('cannot be specified when identifying user by guid')
        end
      end

      context 'when user_guid is too short' do
        let(:user_guid) { '' }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include 'User guid must be between 1 and 200 characters'
        end
      end

      context 'when user_guid is too long' do
        let(:user_guid) { 'B' * (200 + 1) }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include('User guid must be between 1 and 200 characters')
        end
      end
      #
      # context 'when user relationship is more malformed' do
      #   let(:user_data) do
      #     {
      #       origin: user_origin
      #     }
      #   end
      #
      #   it 'is not valid' do
      #     message = subject.new(space_params)
      #     expect(message).to be_invalid
      #     expect(message.errors[:user_origin]).to include 'cannot be specified without specifying the user name'
      #   end
      # end
    end

    context 'space_guid' do
      let(:type) { space_type }

      context 'when not a string' do
        let(:space_guid) { 5 }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).not_to be_valid
          expect(message.errors[:relationships]).to include('Space guid must be a string')
        end
      end

      context 'when it is too short' do
        let(:space_guid) { '' }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include('Space guid must be between 1 and 200 characters')
        end
      end

      context 'when it is too long' do
        let(:space_guid) { 'B' * (200 + 1) }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include 'Space guid must be between 1 and 200 characters'
        end
      end

      context 'when space relationship is malformed' do
        let(:space_data) { 'just-a-string-not-an-object' }

        it 'is not valid' do
          message = subject.new(space_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include 'Space must be structured like this: "space: {"data": {"guid": "valid-guid"}}"'
        end
      end
    end

    context 'organization_guid' do
      let(:type) { org_type }

      context 'when not a string' do
        let(:org_guid) { 5 }

        it 'is not valid' do
          message = subject.new(org_params)
          expect(message).not_to be_valid
          expect(message.errors[:relationships]).to include('Organization guid must be a string')
        end
      end

      context 'when it is too short' do
        let(:org_guid) { '' }

        it 'is not valid' do
          message = subject.new(org_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include 'Organization guid must be between 1 and 200 characters'
        end
      end

      context 'when it is too long' do
        let(:org_guid) { 'B' * (200 + 1) }

        it 'is not valid' do
          message = subject.new(org_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include 'Organization guid must be between 1 and 200 characters'
        end
      end

      context 'when organization relationship is malformed' do
        let(:org_data) { 'just-a-string-not-an-object' }

        it 'is not valid' do
          message = subject.new(org_params)
          expect(message).to be_invalid
          expect(message.errors[:relationships]).to include 'Organization must be structured like this: "organization: {"data": {"guid": "valid-guid"}}"'
        end
      end
    end

    context 'organization_guid and space guid are both provided' do
      let(:org_and_space_params) do
        {
          type: org_type,
          relationships: {
            user: {
              data: { guid: user_guid }
            },
            space: {
              data: { guid: space_guid }
            },
            organization: {
              data: { guid: org_guid }
            },
          }
        }
      end

      it 'is not valid' do
        message = subject.new(org_and_space_params)
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include('Role cannot be associated with both an organization and a space.')
      end
    end
  end
end
