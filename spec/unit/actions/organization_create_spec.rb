require 'spec_helper'
require 'actions/organization_create'

module VCAP::CloudController
  RSpec.describe OrganizationCreate do
    describe 'create' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
      let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }
      subject(:org_create) { OrganizationCreate.new(user_audit_info: user_audit_info) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
        allow(uaa_client).to receive(:usernames_for_ids).with([user.guid]).and_return(
          { user.guid => 'Ragnaros' }
        )
      end

      context 'when creating a non-suspended organization' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({
            name: 'my-organization',
            metadata: {
              labels: {
                release: 'stable',
                'seriouseats.com/potato' => 'mashed'
              },
              annotations: {
                tomorrow: 'land',
                backstreet: 'boys'
              }
            }
          })
        end

        it 'creates a organization' do
          organization = org_create.create(message)

          expect(organization.name).to eq('my-organization')

          expect(organization).to have_labels(
            { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
            { prefix: nil, key: 'release', value: 'stable' }
          )

          expect(organization).to have_annotations(
            { key: 'tomorrow', value: 'land' },
            { key: 'backstreet', value: 'boys' }
          )
        end

        it 'creates an audit event' do
          created_org = org_create.create(message)
          expect(VCAP::CloudController::Event.count).to eq(1)
          org_create_event = VCAP::CloudController::Event.find(type: 'audit.organization.create')
          expect(org_create_event).to exist
          expect(org_create_event.values).to include(
            type: 'audit.organization.create',
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            actee: created_org.guid,
            actee_type: 'organization',
            actee_name: 'my-organization',
            organization_guid: created_org.guid
          )
          expect(org_create_event.metadata).to eq({ 'request' => message.audit_hash })
          expect(org_create_event.timestamp).to be
        end
      end

      it 'creates a suspended organization' do
        message = VCAP::CloudController::OrganizationUpdateMessage.new({
          name: 'my-organization',
          suspended: true
        })
        organization = org_create.create(message)

        expect(organization.name).to eq('my-organization')
        expect(organization.suspended?).to be true
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::Organization).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::OrganizationUpdateMessage.new(name: 'foobar')
          expect {
            org_create.create(message)
          }.to raise_error(OrganizationCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          let(:name) { 'Olsen' }

          before do
            VCAP::CloudController::Organization.create(name: name)
          end

          it 'raises a human-friendly error' do
            message = VCAP::CloudController::OrganizationUpdateMessage.new(name: name)
            expect {
              org_create.create(message)
            }.to raise_error(OrganizationCreate::Error, "Organization '#{name}' already exists.")
          end
        end
      end
    end
  end
end
