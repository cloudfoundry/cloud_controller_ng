require 'spec_helper'
require 'actions/space_create'
require 'models/runtime/space'

module VCAP::CloudController
  RSpec.describe SpaceCreate do
    describe 'create' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:relationships) { { organization: { data: { guid: org.guid } } } }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'gooid', user_guid: 'amelia@cats.com', user_name: 'amelia') }

      context 'when creating a space' do
        let(:message) do
          VCAP::CloudController::SpaceCreateMessage.new(
            name: 'my-space',
            relationships: relationships,
            metadata: {
              labels: {
                release: 'stable',
                'seriouseats.com/potato': 'mashed'
              }
            }
          )
        end
        let!(:space) { SpaceCreate.new(user_audit_info:).create(org, message) }

        it 'creates a space' do
          expect(space.organization).to eq(org)
          expect(space.name).to eq('my-space')
          expect(space).to have_labels(
            { prefix: nil, key_name: 'release', value: 'stable' },
            { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' }
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
            organization_guid: space.organization.guid
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
          expect do
            SpaceCreate.new(user_audit_info:).create(org, message)
          end.to raise_error(SpaceCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          let(:name) { 'Olsen' }

          before do
            VCAP::CloudController::Space.create(organization: org, name: name)
          end

          it 'raises a human-friendly error' do
            message = VCAP::CloudController::SpaceCreateMessage.new(name:)
            expect do
              SpaceCreate.new(user_audit_info:).create(org, message)
            end.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
          end
        end

        context 'when creating spaces concurrently' do
          let(:name) { 'Rose' }

          it 'ensures one creation is successful and the other fails due to name conflict' do
            # First request, should succeed
            message = VCAP::CloudController::SpaceCreateMessage.new(name:)
            expect do
              SpaceCreate.new(user_audit_info:).create(org, message)
            end.not_to raise_error

            # Mock the validation for the second request to simulate the race condition and trigger a unique constraint violation
            allow_any_instance_of(Space).to receive(:validate).and_return(true)

            # Second request, should fail with correct error
            expect do
              SpaceCreate.new(user_audit_info:).create(org, message)
            end.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
          end
        end
      end
    end
  end
end
