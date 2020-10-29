require 'spec_helper'
require 'actions/space_create'
require 'models/runtime/space'

module VCAP::CloudController
  RSpec.describe SpaceCreate do
    describe 'create' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:perm_client) { instance_spy(VCAP::CloudController::Perm::Client) }
      let(:relationships) { { organization: { data: { guid: org.guid } } } }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'gooid', user_guid: 'amelia@cats.com', user_name: 'amelia') }

      context 'when creating a space' do
        let(:message) { VCAP::CloudController::SpaceCreateMessage.new(
          name: 'my-space',
          relationships: relationships,
          metadata: {
            labels: {
              release: 'stable',
              'seriouseats.com/potato': 'mashed'
            }
          }
        )
        }
        let!(:space) { SpaceCreate.new(perm_client: perm_client, user_audit_info: user_audit_info).create(org, message) }

        it 'creates a space' do
          expect(space.organization).to eq(org)
          expect(space.name).to eq('my-space')
          expect(space).to have_labels(
            { prefix: nil, key: 'release', value: 'stable' },
            { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' }
          )
        end

        it 'creates an audit event' do
          expect(VCAP::CloudController::Event.count).to eq(1)
          event = VCAP::CloudController::Event.last

          expect(event.values).to include(
            type: 'audit.space.create',
            actee: space.guid,
            actee_type: 'space',
            actee_name: 'my-space',
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            space_guid: space.guid,
            organization_guid: space.organization.guid,
          )
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::Space).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::SpaceCreateMessage.new(name: 'foobar')
          expect {
            SpaceCreate.new(perm_client: perm_client, user_audit_info: user_audit_info).create(org, message)
          }.to raise_error(SpaceCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          let(:name) { 'Olsen' }

          before do
            VCAP::CloudController::Space.create(organization: org, name: name)
          end

          it 'raises a human-friendly error' do
            message = VCAP::CloudController::SpaceCreateMessage.new(name: name)
            expect {
              SpaceCreate.new(perm_client: perm_client, user_audit_info: user_audit_info).create(org, message)
            }.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
          end
        end

        context 'when it is a db uniqueness error' do
          let(:name) { 'mySpace' }
          it 'handles Space::DBNameUniqueRaceErrors' do
            allow(Space).to receive(:create).and_raise(Space::DBNameUniqueRaceError)

            message = VCAP::CloudController::SpaceCreateMessage.new(name: name)
            expect {
              SpaceCreate.new(perm_client: perm_client, user_audit_info: user_audit_info).create(org, message)
            }.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
          end
        end
      end
    end
  end
end
