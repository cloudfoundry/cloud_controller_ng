require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IsolationSegmentSelector do
    describe '.for_space' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
      let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:isolation_segment_model_2) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:shared_isolation_segment) do
        VCAP::CloudController::IsolationSegmentModel.first(
          guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID
        )
      end

      context 'when the org has a default' do
        context 'and the default is the shared isolation segment' do
          before do
            assigner.assign(shared_isolation_segment, [org])
          end

          it 'does not set an isolation segment' do
            expect(described_class.for_space(space)).to be_nil
          end
        end

        context 'and the default is not the shared isolation segment' do
          before do
            assigner.assign(isolation_segment_model, [org])
            org.update(default_isolation_segment_model: isolation_segment_model)
          end

          it 'sets the isolation segment' do
            expect(described_class.for_space(space)).to eq(isolation_segment_model.name)
          end

          context 'and the space from that org has an isolation segment' do
            context 'and the isolation segment is the shared isolation segment' do
              before do
                assigner.assign(shared_isolation_segment, [org])
                space.isolation_segment_model = shared_isolation_segment
                space.save
              end

              it 'does not set the isolation segment' do
                expect(described_class.for_space(space)).to be_nil
              end
            end

            context 'and the isolation segment is not the shared or the default' do
              before do
                assigner.assign(isolation_segment_model_2, [org])
                space.isolation_segment_model = isolation_segment_model_2
                space.save
              end

              it 'sets the IS from the space' do
                expect(described_class.for_space(space)).to eq(isolation_segment_model_2.name)
              end
            end
          end
        end
      end

      context 'when the org does not have a default' do
        context 'and the space from that org has an isolation segment' do
          context 'and the isolation segment is not the shared isolation segment' do
            before do
              assigner.assign(isolation_segment_model, [org])
              space.isolation_segment_model = isolation_segment_model
              space.save
            end

            it 'sets the isolation segment' do
              expect(described_class.for_space(space)).to eq(isolation_segment_model.name)
            end
          end
        end
      end
    end
  end
end
