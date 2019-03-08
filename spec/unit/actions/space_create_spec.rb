require 'spec_helper'
require 'actions/space_create'
require 'models/runtime/space'

module VCAP::CloudController
  RSpec.describe SpaceCreate do
    describe 'create' do
      let(:org) { FactoryBot.create(:organization) }
      let(:perm_client) { instance_spy(VCAP::CloudController::Perm::Client) }
      let(:relationships) { { organization: { data: { guid: org.guid } } } }

      it 'creates a space' do
        message = VCAP::CloudController::SpaceCreateMessage.new(
          name: 'my-space',
          relationships: relationships,
          metadata: {
              labels: {
                  release: 'stable',
                  'seriouseats.com/potato': 'mashed'
              }
          }
        )
        space = SpaceCreate.new(perm_client: perm_client).create(org, message)

        expect(space.organization).to eq(org)
        expect(space.name).to eq('my-space')
        expect(space.labels.map(&:value)).to contain_exactly('stable', 'mashed')
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::Space).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::SpaceCreateMessage.new(name: 'foobar')
          expect {
            SpaceCreate.new(perm_client: perm_client).create(org, message)
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
              SpaceCreate.new(perm_client: perm_client).create(org, message)
            }.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
          end
        end

        context 'when it is a db uniqueness error' do
          let(:name) { 'mySpace' }
          it 'handles Space::DBNameUniqueRaceErrors' do
            allow(Space).to receive(:create).and_raise(Space::DBNameUniqueRaceError)

            message = VCAP::CloudController::SpaceCreateMessage.new(name: name)
            expect {
              SpaceCreate.new(perm_client: perm_client).create(org, message)
            }.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
          end
        end
      end
    end
  end
end
