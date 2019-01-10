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

        expect(iso_seg.labels.map(&:key_name)).to contain_exactly('potato', 'release')
        expect(iso_seg.labels.map(&:key_prefix)).to contain_exactly('seriouseats.com', nil)
        expect(iso_seg.labels.map(&:value)).to contain_exactly('stable', 'mashed')

        expect(iso_seg.annotations.map(&:key)).to contain_exactly('tomorrow', 'backstreet')
        expect(iso_seg.annotations.map(&:value)).to contain_exactly('land', 'boys')
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
