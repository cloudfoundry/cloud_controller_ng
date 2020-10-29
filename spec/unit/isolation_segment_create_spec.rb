require 'spec_helper'
require 'actions/isolation_segment_create'

module VCAP::CloudController
  RSpec.describe IsolationSegmentCreate do
    describe 'create' do
      it 'creates a isolation segment' do
        message = VCAP::CloudController::IsolationSegmentCreateMessage.new({
          name: 'my-iso-seg',
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
        iso_seg = IsolationSegmentCreate.create(message)

        expect(iso_seg.name).to eq('my-iso-seg')
        expect(iso_seg).to have_labels(
          { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
          { prefix: nil, key: 'release', value: 'stable' }
        )
        expect(iso_seg).to have_annotations(
          { key: 'tomorrow', value: 'land' },
          { key: 'backstreet', value: 'boys' }
        )
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::IsolationSegmentModel).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::IsolationSegmentCreateMessage.new(name: 'foobar')
          expect {
            IsolationSegmentCreate.create(message)
          }.to raise_error(IsolationSegmentCreate::Error, 'blork is busted')
        end
      end
    end
  end
end
