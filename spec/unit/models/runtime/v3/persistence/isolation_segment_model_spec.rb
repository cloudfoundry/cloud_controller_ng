require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IsolationSegmentModel do
    let(:isolation_segment) { IsolationSegmentModel.make }

    describe 'associations' do
      describe 'spaces' do
        let(:space_1) { Space.make }
        let(:space_2) { Space.make }

        it 'one isolation_segment can reference a single spaces' do
          isolation_segment.add_space(space_1)

          expect(isolation_segment.spaces).to include(space_1)
          expect(space_1.isolation_segment_model).to eq isolation_segment
        end

        it 'one isolation_segment can reference multiple spaces' do
          isolation_segment.add_space(space_1)
          isolation_segment.add_space(space_2)

          expect(isolation_segment.spaces).to include(space_1, space_2)
          expect(space_1.isolation_segment_model).to eq isolation_segment
          expect(space_2.isolation_segment_model).to eq isolation_segment
        end

        it 'multiple isolation_segments cannot refernece the same space' do
          isolation_segment_2 = IsolationSegmentModel.make

          isolation_segment.add_space(space_1)
          isolation_segment_2.add_space(space_1)

          expect(isolation_segment.spaces).to be_empty
          expect(isolation_segment_2.spaces).to include(space_1)
        end

        context 'removing spaces from isolation segments' do
          it 'properly removes the associations' do
            isolation_segment.add_space(space_1)
            space_1.reload

            isolation_segment.remove_space(space_1)
            isolation_segment.reload

            expect(isolation_segment.spaces).to be_empty
            expect(space_1.isolation_segment_model).to be_nil
          end
        end
      end
    end

    describe 'validations' do
      it 'requires a name' do
        expect {
          IsolationSegmentModel.make(name: nil)
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names can only contain non-blank unicode characters')
      end

      it 'requires a non blank name' do
        expect {
          IsolationSegmentModel.make(name: '')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names can only contain non-blank unicode characters')
      end

      it 'requires a unique name' do
        IsolationSegmentModel.make(name: 'segment1')

        expect {
          IsolationSegmentModel.make(name: 'segment1')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names are case insensitive and must be unique')
      end

      it 'uniqueness is case insensitive' do
        IsolationSegmentModel.make(name: 'lowercase')

        expect {
          IsolationSegmentModel.make(name: 'lowerCase')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names are case insensitive and must be unique')
      end

      it 'should allow standard ascii characters' do
        expect {
          IsolationSegmentModel.make(name: "A -_- word 2!?()\'\"&+.")
        }.to_not raise_error
      end

      it 'should allow backslash characters' do
        expect {
          IsolationSegmentModel.make(name: 'a \\ word')
        }.to_not raise_error
      end

      it 'should allow unicode characters' do
        expect {
          IsolationSegmentModel.make(name: '防御力¡')
        }.to_not raise_error
      end

      it 'should not allow newline characters' do
        expect {
          IsolationSegmentModel.make(name: "a \n word")
        }.to raise_error(Sequel::ValidationFailed)
      end

      it 'should not allow escape characters' do
        expect {
          IsolationSegmentModel.make(name: "a \e word")
        }.to raise_error(Sequel::ValidationFailed)
      end
    end

    describe '#before_destroy' do
      let!(:space) { Space.make(isolation_segment_guid: isolation_segment.guid) }

      it 'raises an error if there are still spaces associated' do
        expect { isolation_segment.destroy }.to raise_error(CloudController::Errors::ApiError, /Please delete the space associations for your isolation segment/)
      end
    end
  end
end
