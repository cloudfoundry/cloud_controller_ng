require 'spec_helper'
require 'actions/space_create'

RSpec.describe SpaceCreate do
  describe 'create' do
    let(:org) { VCAP::CloudController::Organization.make }
    it 'creates a space' do
      message = VCAP::CloudController::SpaceCreateMessage.new(name: 'my-space')
      space   = SpaceCreate.new.create(org, message)

      expect(space.organization).to eq(org)
      expect(space.name).to eq('my-space')
    end

    context 'when a model validation fails' do
      it 'raises an error' do
        errors = Sequel::Model::Errors.new
        errors.add(:blork, 'is busted')
        expect(VCAP::CloudController::Space).to receive(:create).
          and_raise(Sequel::ValidationFailed.new(errors))

        message = VCAP::CloudController::SpaceCreateMessage.new(name: 'foobar')
        expect {
          SpaceCreate.new.create(org, message)
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
            SpaceCreate.new.create(org, message)
          }.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
        end
      end
    end
  end
end
