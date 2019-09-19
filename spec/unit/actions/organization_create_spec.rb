require 'spec_helper'
require 'actions/organization_create'

module VCAP::CloudController
  RSpec.describe OrganizationCreate do
    describe 'create' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
      let(:perm_client) { instance_spy(VCAP::CloudController::Perm::Client) }
      subject(:org_create) { OrganizationCreate.new(perm_client: perm_client, user_audit_info: user_audit_info) }

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

          expect(organization.labels.map(&:key_name)).to contain_exactly('potato', 'release')
          expect(organization.labels.map(&:key_prefix)).to contain_exactly('seriouseats.com', nil)
          expect(organization.labels.map(&:value)).to contain_exactly('stable', 'mashed')

          expect(organization.annotations.map(&:key)).to contain_exactly('tomorrow', 'backstreet')
          expect(organization.annotations.map(&:value)).to contain_exactly('land', 'boys')
        end

        it 'creates an audit event' do
          created_org = org_create.create(message)
          expect(VCAP::CloudController::Event.count).to eq(1)
          event = VCAP::CloudController::Event.first
          expect(event.values).to include(
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
          expect(event.metadata).to eq({ 'request' => message.audit_hash })
          expect(event.timestamp).to be
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
