require 'spec_helper'
require 'actions/role_create'
require 'messages/role_create_message'

module VCAP::CloudController
  RSpec.describe RoleCreate do
    subject { RoleCreate }

    let(:db) { Sequel::Model.db }
    let(:message) { RoleCreateMessage.new(params) }
    let(:space) { Space.make }
    let(:user) { User.make }

    let(:params) do
      {
        type: type,
        relationships: {
          user: { data: { guid: user.guid } },
          space: { data: { guid: space.guid } },
        }
      }
    end

    before do
      space.organization.add_user(user)
    end

    describe '#create' do
      context 'creating a space auditor' do
        let(:type) { RoleTypes::SPACE_AUDITOR }

        it 'creates a space auditor role' do
          created_role = nil
          expect {
            created_role = subject.create(message: message)
          }.to change { db[:spaces_auditors].count }.by(1)

          expect(created_role[:guid]).to be_a_guid
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::SpaceAuditor).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create(message: message)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:uaa_client) { double(:uaa_client) }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
              allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
              )

              VCAP::CloudController::RoleCreate.create(message: message)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create(message: message)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has 'space_auditor' role in space '#{space.name}'.")
            end
          end
        end
      end

      context 'creating a space developer' do
        let(:type) { RoleTypes::SPACE_DEVELOPER }

        it 'creates a space developer role' do
          created_role = nil
          expect {
            created_role = subject.create(message: message)
          }.to change { db[:spaces_developers].count }.by(1)

          expect(created_role[:guid]).to be_a_guid
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::SpaceDeveloper).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create(message: message)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:uaa_client) { double(:uaa_client) }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
              allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
              )

              VCAP::CloudController::RoleCreate.create(message: message)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create(message: message)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has 'space_developer' role in space '#{space.name}'.")
            end
          end
        end
      end

      context 'creating a space manager' do
        let(:type) { RoleTypes::SPACE_MANAGER }

        it 'creates a space manager role' do
          created_role = nil
          expect {
            created_role = subject.create(message: message)
          }.to change { Sequel::Model.db[:spaces_managers].count }.by(1)

          expect(created_role[:guid]).to be_a_guid
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::SpaceManager).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create(message: message)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:uaa_client) { double(:uaa_client) }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
              allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
              )

              VCAP::CloudController::RoleCreate.create(message: message)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create(message: message)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has 'space_manager' role in space '#{space.name}'.")
            end
          end
        end
      end
    end
  end
end
