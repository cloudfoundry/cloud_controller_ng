require 'spec_helper'
require 'actions/role_create'
require 'messages/role_create_message'

module VCAP::CloudController
  RSpec.describe RoleCreate do
    subject { RoleCreate }

    let(:db) { Sequel::Model.db }
    let(:space) { Space.make }
    let(:org) { space.organization }
    let(:user) { User.make }

    describe '#create_space_role' do
      context 'when the user has a role in the parent org' do
        before do
          space.organization.add_user(user)
        end

        context 'creating a space auditor' do
          let(:type) { RoleTypes::SPACE_AUDITOR }

          it 'creates a space auditor role' do
            created_role = nil
            expect {
              created_role = subject.create_space_role(type: type, user: user, space: space)
            }.to change { VCAP::CloudController::SpaceAuditor.count }.by(1)

            expect(created_role.guid).to be_a_guid
          end

          context 'when a model validation fails' do
            it 'raises an error' do
              errors = Sequel::Model::Errors.new
              errors.add(:blork, 'is busted')
              expect(VCAP::CloudController::SpaceAuditor).to receive(:create).
                and_raise(Sequel::ValidationFailed.new(errors))
              expect {
                subject.create_space_role(type: type, user: user, space: space)
              }.to raise_error(RoleCreate::Error, 'blork is busted')
            end

            context 'when it is a uniqueness error' do
              let(:uaa_client) { double(:uaa_client) }

              before do
                allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
                allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                  { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
                )

                VCAP::CloudController::RoleCreate.create_space_role(type: type, user: user, space: space)
              end

              it 'raises a human-friendly error' do
                expect {
                  subject.create_space_role(type: type, user: user, space: space)
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
              created_role = subject.create_space_role(type: type, user: user, space: space)
            }.to change { VCAP::CloudController::SpaceDeveloper.count }.by(1)

            expect(created_role.guid).to be_a_guid
          end

          context 'when a model validation fails' do
            it 'raises an error' do
              errors = Sequel::Model::Errors.new
              errors.add(:blork, 'is busted')
              expect(VCAP::CloudController::SpaceDeveloper).to receive(:create).
                and_raise(Sequel::ValidationFailed.new(errors))
              expect {
                subject.create_space_role(type: type, user: user, space: space)
              }.to raise_error(RoleCreate::Error, 'blork is busted')
            end

            context 'when it is a uniqueness error' do
              let(:uaa_client) { double(:uaa_client) }

              before do
                allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
                allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                  { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
                )

                VCAP::CloudController::RoleCreate.create_space_role(type: type, user: user, space: space)
              end

              it 'raises a human-friendly error' do
                expect {
                  subject.create_space_role(type: type, user: user, space: space)
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
              created_role = subject.create_space_role(type: type, user: user, space: space)
            }.to change { VCAP::CloudController::SpaceManager.count }.by(1)

            expect(created_role.guid).to be_a_guid
          end

          context 'when a model validation fails' do
            it 'raises an error' do
              errors = Sequel::Model::Errors.new
              errors.add(:blork, 'is busted')
              expect(VCAP::CloudController::SpaceManager).to receive(:create).
                and_raise(Sequel::ValidationFailed.new(errors))
              expect {
                subject.create_space_role(type: type, user: user, space: space)
              }.to raise_error(RoleCreate::Error, 'blork is busted')
            end

            context 'when it is a uniqueness error' do
              let(:uaa_client) { double(:uaa_client) }

              before do
                allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
                allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                  { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
                )

                VCAP::CloudController::RoleCreate.create_space_role(type: type, user: user, space: space)
              end

              it 'raises a human-friendly error' do
                expect {
                  subject.create_space_role(type: type, user: user, space: space)
                }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has 'space_manager' role in space '#{space.name}'.")
              end
            end
          end
        end
      end

      context 'when the user does not have a role in the parent organization' do
        let(:type) { RoleTypes::SPACE_MANAGER }

        it 'raises an error' do
          expect {
            subject.create_space_role(type: type, user: user, space: space)
          }.to raise_error(RoleCreate::Error, "Users cannot be assigned roles in a space if they do not have a role in that space's organization.")
        end
      end
    end

    context '#create_organization_role' do
      context 'creating an organization user' do
        let(:type) { RoleTypes::ORGANIZATION_USER }

        it 'creates an organization user role' do
          created_role = nil
          expect {
            created_role = subject.create_organization_role(type: type, user: user, organization: org)
          }.to change { VCAP::CloudController::OrganizationUser.count }.by(1)

          expect(created_role.guid).to be_a_guid
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::OrganizationUser).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create_organization_role(type: type, user: user, organization: org)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:uaa_client) { double(:uaa_client) }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
              allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
              )

              VCAP::CloudController::RoleCreate.create_organization_role(type: type, user: user, organization: org)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create_organization_role(type: type, user: user, organization: org)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has '#{type}' role in organization '#{org.name}'.")
            end
          end
        end
      end

      context 'creating an organization auditor' do
        let(:type) { RoleTypes::ORGANIZATION_AUDITOR }

        it 'creates an organization user role' do
          created_role = nil
          expect {
            created_role = subject.create_organization_role(type: type, user: user, organization: org)
          }.to change { VCAP::CloudController::OrganizationAuditor.count }.by(1)

          expect(created_role.guid).to be_a_guid
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::OrganizationAuditor).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create_organization_role(type: type, user: user, organization: org)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:uaa_client) { double(:uaa_client) }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
              allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
              )

              VCAP::CloudController::RoleCreate.create_organization_role(type: type, user: user, organization: org)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create_organization_role(type: type, user: user, organization: org)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has '#{type}' role in organization '#{org.name}'.")
            end
          end
        end
      end

      context 'creating an organization manager' do
        let(:type) { RoleTypes::ORGANIZATION_MANAGER }

        it 'creates an organization user role' do
          created_role = nil
          expect {
            created_role = subject.create_organization_role(type: type, user: user, organization: org)
          }.to change { VCAP::CloudController::OrganizationManager.count }.by(1)

          expect(created_role.guid).to be_a_guid
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::OrganizationManager).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create_organization_role(type: type, user: user, organization: org)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:uaa_client) { double(:uaa_client) }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
              allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
              )

              VCAP::CloudController::RoleCreate.create_organization_role(type: type, user: user, organization: org)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create_organization_role(type: type, user: user, organization: org)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has '#{type}' role in organization '#{org.name}'.")
            end
          end
        end
      end

      context 'creating an organization billing manager' do
        let(:type) { RoleTypes::ORGANIZATION_BILLING_MANAGER }

        it 'creates an organization user role' do
          created_role = nil
          expect {
            created_role = subject.create_organization_role(type: type, user: user, organization: org)
          }.to change { VCAP::CloudController::OrganizationBillingManager.count }.by(1)

          expect(created_role.guid).to be_a_guid
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(VCAP::CloudController::OrganizationBillingManager).to receive(:create).
              and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create_organization_role(type: type, user: user, organization: org)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:uaa_client) { double(:uaa_client) }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
              allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
                { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
              )

              VCAP::CloudController::RoleCreate.create_organization_role(type: type, user: user, organization: org)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create_organization_role(type: type, user: user, organization: org)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has '#{type}' role in organization '#{org.name}'.")
            end
          end
        end
      end
    end
  end
end
