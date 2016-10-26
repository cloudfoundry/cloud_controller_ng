require 'spec_helper'
require 'isolation_segment_assign'
require 'isolation_segment_unassign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUnassign do
    let(:assigner) { IsolationSegmentAssign.new }
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:org) { Organization.make }

    context 'when the segment is not assigned to the org' do
      it 'is idempotent' do
        subject.unassign(isolation_segment_model, org)
        expect(org.isolation_segment_models).to eq([])
      end

      context 'when there are other segments assigned to the org' do
        let(:isolation_segment_model2) { IsolationSegmentModel.make }
        before do
          assigner.assign(isolation_segment_model2, org)
          expect(org.isolation_segment_model).to eq(isolation_segment_model2)
        end

        it 'does not remove any other assigned segments' do
          subject.unassign(isolation_segment_model, org)
          expect(org.isolation_segment_models).to eq([isolation_segment_model2])
        end

        it "does not change the org's default isolation segment" do
          subject.unassign(isolation_segment_model, org)
          expect(org.isolation_segment_model).to eq(isolation_segment_model2)
        end
      end
    end

    context 'and the segment is assigned to the org' do
      before do
        assigner.assign(isolation_segment_model, org)
      end

      it "removes the segment from the org's allowed list" do
        subject.unassign(isolation_segment_model, org)
        expect(org.isolation_segment_models).to eq([])
      end

      it 'unsets the default isolation segment for the org' do
        subject.unassign(isolation_segment_model, org)
        expect(org.isolation_segment_model).to be_nil
      end

      context 'and the segment has been assigned to a space owned by the org' do
        let(:space) { Space.make(organization: org) }

        before do
          space.update(isolation_segment_model: isolation_segment_model)
          space.save
          space.reload
        end

        it 'does not remove the segment from the allowed list' do
          expect {
            subject.unassign(isolation_segment_model, org)
          }.to raise_error IsolationSegmentUnassign::IsolationSegmentUnassignError, 'Please delete the Space associations for your Isolation Segment.'

          expect(org.isolation_segment_models).to eq([isolation_segment_model])
        end
      end

      context 'when there are other segments assigned to the org' do
        let(:isolation_segment_model2) { IsolationSegmentModel.make }
        before do
          assigner.assign(isolation_segment_model2, org)
        end

        it 'does not remove any other assigned segments' do
          subject.unassign(isolation_segment_model2, org)
          expect(org.isolation_segment_models).to eq([isolation_segment_model])
        end

        it "does not change the org's default isolation segment" do
          org.isolation_segment_model = isolation_segment_model2
          subject.unassign(isolation_segment_model, org)

          expect(org.isolation_segment_model).to eq(isolation_segment_model2)
        end

        context 'and the segment is the default for the org' do
          before do
            org.isolation_segment_model = isolation_segment_model
          end

          it 'does not remove the default segment from the allowed list' do
            expect {
              subject.unassign(isolation_segment_model, org)
            }.to raise_error IsolationSegmentUnassign::IsolationSegmentUnassignError, /This operation can only be completed if another Isolation Segment is set as the default/

            expect(org.isolation_segment_models).to match_array([
              isolation_segment_model,
              isolation_segment_model2
            ])
          end
        end

        context 'and the segment has been assigned to a space owned by the org' do
          let(:space) { Space.make(organization: org) }

          before do
            space.update(isolation_segment_model: isolation_segment_model)
            space.save
            space.reload
          end

          it 'does not remove the segment from the allowed list' do
            expect {
              subject.unassign(isolation_segment_model, org)
            }.to raise_error IsolationSegmentUnassign::IsolationSegmentUnassignError, 'Please delete the Space associations for your Isolation Segment.'

            expect(org.isolation_segment_models).to match_array([
              isolation_segment_model,
              isolation_segment_model2
            ])
          end
        end
      end
    end
  end
end
