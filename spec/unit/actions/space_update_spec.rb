require 'spec_helper'
require 'actions/space_update'

module VCAP::CloudController
  RSpec.describe SpaceUpdate do
    describe 'update' do
      let(:org) { FactoryBot.create(:organization) }
      let(:space) { FactoryBot.create(:space, name: 'old-space-name', organization: org) }

      context 'when a name and label are requested' do
        let(:message) do
          VCAP::CloudController::SpaceUpdateMessage.new({
           name: 'new-space-name',
           metadata: {
              labels: {
                freaky: 'wednesday',
              },
            },
                                                               }
          )
        end

        it 'updates a space' do
          updated_space = SpaceUpdate.new.update(space, message)
          expect(updated_space.reload.name).to eq 'new-space-name'
        end

        it 'updates metadata' do
          updated_space = SpaceUpdate.new.update(space, message)
          expect(updated_space.reload.labels.first.key_name).to eq 'freaky'
          expect(updated_space.reload.labels.first.value).to eq 'wednesday'
        end

        context 'when model validation fails' do
          it 'errors' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(space).to receive(:save).
              and_raise(Sequel::ValidationFailed.new(errors))

            expect {
              SpaceUpdate.new.update(space, message)
            }.to raise_error(SpaceUpdate::Error, 'blork is busted')
          end
        end

        context 'when the space name is not unique' do
          it 'errors usefully' do
            FactoryBot.create(:space, name: 'new-space-name', organization: org)

            expect {
              SpaceUpdate.new.update(space, message)
            }.to raise_error(SpaceUpdate::Error, 'Name must be unique per organization')
          end
        end
      end

      context 'when nothing is requested' do
        let(:message) do
          VCAP::CloudController::SpaceUpdateMessage.new({})
        end

        it 'does not change the space name' do
          updated_space = SpaceUpdate.new.update(space, message)
          expect(updated_space.reload.name).to eq 'old-space-name'
        end
      end
    end
  end
end
