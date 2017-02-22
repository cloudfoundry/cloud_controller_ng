require 'spec_helper'

require 'isolation_segment_assign'
require 'isolation_segment_unassign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentModel do
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:isolation_segment_model_2) { IsolationSegmentModel.make }

    let(:assigner) { IsolationSegmentAssign.new }
    let(:unassigner) { IsolationSegmentUnassign.new }

    describe 'associations' do
      describe 'spaces' do
        let(:space_1) { Space.make }
        let(:space_2) { Space.make }

        context 'when the space is not part of an entitled organization' do
          it 'does not add the space' do
            expect {
              isolation_segment_model.add_space(space_1)
            }.to raise_error(CloudController::Errors::ApiError, /Only Isolation Segments in the Organization/)
          end
        end

        context "and the Isolation Segment has been added to the space's organization" do
          before do
            assigner.assign(isolation_segment_model, [space_1.organization, space_2.organization])
            assigner.assign(isolation_segment_model_2, [space_1.organization, space_2.organization])
          end

          it 'one isolation_segment can reference a single space' do
            isolation_segment_model.add_space(space_1)

            expect(isolation_segment_model.spaces).to include(space_1)
            expect(space_1.isolation_segment_model).to eq isolation_segment_model
          end

          it 'one isolation_segment can reference multiple spaces' do
            isolation_segment_model.add_space(space_1)
            isolation_segment_model.add_space(space_2)

            expect(isolation_segment_model.spaces).to include(space_1, space_2)
            expect(space_1.isolation_segment_model).to eq isolation_segment_model
            expect(space_2.isolation_segment_model).to eq isolation_segment_model
          end

          it 'multiple isolation_segments cannot reference the same space' do
            isolation_segment_model.add_space(space_1)
            isolation_segment_model_2.add_space(space_1)

            expect(isolation_segment_model.spaces).to be_empty
            expect(isolation_segment_model_2.spaces).to include(space_1)
          end

          context 'removing spaces from isolation segments' do
            it 'properly removes the associations' do
              isolation_segment_model.add_space(space_1)
              space_1.reload

              isolation_segment_model.remove_space(space_1)
              isolation_segment_model.reload

              expect(isolation_segment_model.spaces).to be_empty
              expect(space_1.isolation_segment_model).to be_nil
            end
          end
        end
      end

      describe 'organizations' do
        let(:org) { Organization.make }
        let(:org_1) { Organization.make }
        let(:org_2) { Organization.make }

        it 'allows one isolation segment to be referenced by multiple organizations' do
          assigner.assign(isolation_segment_model, [org_1, org_2])

          expect(isolation_segment_model.organizations).to contain_exactly(org_1, org_2)
          expect(org_1.isolation_segment_models).to contain_exactly(isolation_segment_model)
          expect(org_2.isolation_segment_models).to contain_exactly(isolation_segment_model)
        end

        it 'allows multiple isolation segments to be applied to one organization' do
          isolation_segment_model_2 = IsolationSegmentModel.make

          assigner.assign(isolation_segment_model, [org_1])
          assigner.assign(isolation_segment_model_2, [org_1])

          expect(isolation_segment_model.organizations).to contain_exactly(org_1)
          expect(isolation_segment_model_2.organizations).to contain_exactly(org_1)
          expect(org_1.isolation_segment_models).to contain_exactly(isolation_segment_model, isolation_segment_model_2)
        end

        context 'when adding isolation segments to the allowed list' do
          context 'and one isolation segment is in allowed list' do
            before do
              assigner.assign(isolation_segment_model, [org])
            end

            it 'can be removed' do
              unassigner.unassign(isolation_segment_model, org)

              expect(isolation_segment_model.organizations).to be_empty
              expect(org.isolation_segment_models).to be_empty
              expect(org.default_isolation_segment_model).to be_nil
            end
          end
        end
      end
    end

    describe 'validations' do
      it 'requires a name' do
        expect {
          IsolationSegmentModel.make(name: nil)
        }.to raise_error(Sequel::ValidationFailed, 'Isolation Segment names can only contain non-blank unicode characters')
      end

      it 'requires a non blank name' do
        expect {
          IsolationSegmentModel.make(name: '')
        }.to raise_error(Sequel::ValidationFailed, 'Isolation Segment names can only contain non-blank unicode characters')
      end

      it 'requires a unique name' do
        IsolationSegmentModel.make(name: 'segment1')

        expect {
          IsolationSegmentModel.make(name: 'segment1')
        }.to raise_error(Sequel::ValidationFailed, 'Isolation Segment names are case insensitive and must be unique')
      end

      it 'uniqueness is case insensitive' do
        IsolationSegmentModel.make(name: 'lowercase')

        expect {
          IsolationSegmentModel.make(name: 'lowerCase')
        }.to raise_error(Sequel::ValidationFailed, 'Isolation Segment names are case insensitive and must be unique')
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

    describe '#is_shared_segment?' do
      it 'returns false' do
        expect(isolation_segment_model.is_shared_segment?).to be false
      end

      context 'when the guids match' do
        let(:isolation_segment_model) { IsolationSegmentModel.first(guid: IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID) }

        it 'returns true' do
          expect(isolation_segment_model.is_shared_segment?).to be true
        end
      end
    end
  end
end
