require 'spec_helper'
require 'actions/role_create'
require 'messages/role_create_message'

module VCAP::CloudController
  RSpec.describe RoleCreate do
    let(:db) { Sequel::Model.db }
    let(:space) { Space.make }
    let(:org) { space.organization }
    let(:user) { User.make }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'amelia@cats.com', user_guid: 'gooid') }
    let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
      allow(uaa_client).to receive(:usernames_for_ids).with([user.guid]).and_return(
        { user.guid => 'mona' }
      )
    end

    subject { RoleCreate.new(message, user_audit_info) }

    describe '#create_space_role' do
      let(:message) do
        RoleCreateMessage.new({
          type: type,
          relationships: {
            user: { data: { guid: user.guid } },
            space: { data: { guid: space.guid } }
          }
        })
      end

      shared_examples 'space role creation' do |opts|
        it 'creates the role' do
          created_role = nil
          expect {
            created_role = subject.create_space_role(type: type, user: user, space: space)
          }.to change { opts[:model].count }.by(1)

          expect(created_role.guid).to be_a_guid
        end

        it 'records an audit event' do
          expect {
            subject.create_space_role(type: type, user: user, space: space)
          }.to change { Event.count }.by(1)

          event = Event.last
          expect(event.type).to eq(opts[:event_type])
          expect(event.space_guid).to eq(space.guid)
          expect(event.organization_guid).to eq(space.organization.guid)
          expect(event.metadata).to eq({ 'request' => message.audit_hash })
          expect(event.target_name).to eq('mona')
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(opts[:model]).to receive(:create).and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create_space_role(type: type, user: user, space: space)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            before do
              subject.create_space_role(type: type, user: user, space: space)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create_space_role(type: type, user: user, space: space)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has '#{type}' role in space '#{space.name}'.")
            end
          end
        end
      end

      context 'when the user has a role in the parent org' do
        before do
          space.organization.add_user(user)
        end

        context 'creating a space auditor' do
          let(:type) { RoleTypes::SPACE_AUDITOR }

          it_behaves_like 'space role creation', {
            model: VCAP::CloudController::SpaceAuditor,
            event_type: 'audit.user.space_auditor_add'
          }
        end

        context 'creating a space developer and adds the audit event' do
          let(:type) { RoleTypes::SPACE_DEVELOPER }

          it_behaves_like 'space role creation', {
            model: VCAP::CloudController::SpaceDeveloper,
            event_type: 'audit.user.space_developer_add'
          }
        end

        context 'creating a space manager' do
          let(:type) { RoleTypes::SPACE_MANAGER }

          it_behaves_like 'space role creation', {
            model: VCAP::CloudController::SpaceManager,
            event_type: 'audit.user.space_manager_add'
          }
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
      let(:message) do
        RoleCreateMessage.new({
          type: type,
          relationships: {
            user: { data: { guid: user.guid } },
            organization: { data: { guid: org.guid } }
          }
        })
      end

      shared_examples 'org role creation' do |opts|
        it 'creates the role' do
          created_role = nil
          expect {
            created_role = subject.create_organization_role(type: type, user: user, organization: org)
          }.to change { opts[:model].count }.by(1)

          expect(created_role.guid).to be_a_guid
        end

        it 'records an audit event' do
          expect {
            subject.create_organization_role(type: type, user: user, organization: org)
          }.to change { Event.count }.by(1)

          event = Event.last
          expect(event.type).to eq(opts[:event_type])
          expect(event.organization_guid).to eq(org.guid)
          expect(event.metadata).to eq({ 'request' => message.audit_hash })
          expect(event.target_name).to eq('mona')
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(opts[:model]).to receive(:create).and_raise(Sequel::ValidationFailed.new(errors))
            expect {
              subject.create_organization_role(type: type, user: user, organization: org)
            }.to raise_error(RoleCreate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            before do
              subject.create_organization_role(type: type, user: user, organization: org)
            end

            it 'raises a human-friendly error' do
              expect {
                subject.create_organization_role(type: type, user: user, organization: org)
              }.to raise_error(RoleCreate::Error, "User '#{user.presentation_name}' already has '#{type}' role in organization '#{org.name}'.")
            end
          end
        end
      end

      context 'creating an organization user' do
        let(:type) { RoleTypes::ORGANIZATION_USER }

        it_behaves_like 'org role creation', {
          model: VCAP::CloudController::OrganizationUser,
          event_type: 'audit.user.organization_user_add'
        }
      end

      context 'creating an organization auditor' do
        let(:type) { RoleTypes::ORGANIZATION_AUDITOR }

        it_behaves_like 'org role creation', {
          model: VCAP::CloudController::OrganizationAuditor,
          event_type: 'audit.user.organization_auditor_add'
        }
      end

      context 'creating an organization manager' do
        let(:type) { RoleTypes::ORGANIZATION_MANAGER }

        it_behaves_like 'org role creation', {
          model: VCAP::CloudController::OrganizationManager,
          event_type: 'audit.user.organization_manager_add'
        }
      end

      context 'creating an organization billing manager' do
        let(:type) { RoleTypes::ORGANIZATION_BILLING_MANAGER }

        it_behaves_like 'org role creation', {
          model: VCAP::CloudController::OrganizationBillingManager,
          event_type: 'audit.user.organization_billing_manager_add'
        }
      end
    end
  end
end
