require 'spec_helper'
require 'isolation_segment_assign'
require 'isolation_segment_unassign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUnassign do
    let(:assigner) { IsolationSegmentAssign.new }
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:isolation_segment_model_2) { IsolationSegmentModel.make }
    let(:org) { Organization.make }
    let(:org2) { Organization.make }

    context 'when an Isolation Segment is not assigned to any Orgs' do
      it 'is idempotent' do
        subject.unassign(isolation_segment_model, org)
        expect(org.isolation_segment_models).to eq([])
      end
    end

    context 'when Organizations have been assigned to an Isolation Segment' do
      before do
        assigner.assign(isolation_segment_model, [org, org2])
      end

      it 'can remove a single org form the Isolation Segment' do
        subject.unassign(isolation_segment_model, org)
        expect(isolation_segment_model.organizations).to eq([org2])
      end

      context 'and the Organization has the Isolation segment as the default' do
        before do
          org.update(default_isolation_segment_model: isolation_segment_model)
        end

        it 'does not remove the organization\'s default Isolation Segment' do
          expect {
            subject.unassign(isolation_segment_model, org)
          }.to raise_error CloudController::Errors::ApiError, /default isolation segment/i

          org.reload
          expect(org.default_isolation_segment_model).to eq(isolation_segment_model)
        end
      end

      context 'and the Organization has a space assigned' do
        let!(:space) { Space.make(organization: org) }

        it 'allows the isolation segment to remove the organization' do
          subject.unassign(isolation_segment_model, org)
          expect(isolation_segment_model.organizations).to eq([org2])
        end

        context 'and the space has an app' do
          before do
            AppModel.make(space: space)
          end

          it 'removes the Organization from the Isolation Segment' do
            subject.unassign(isolation_segment_model, org)
            expect(isolation_segment_model.organizations).to eq([org2])
          end
        end

        context 'and the space is assigned the Isolation Segment' do
          before do
            space.update(isolation_segment_model: isolation_segment_model)
          end

          it 'does not remove the org from the Isolation Segment' do
            expect {
              subject.unassign(isolation_segment_model, org)
            }.to raise_error CloudController::Errors::ApiError, /assigned to.*#{space.name}/i

            expect(isolation_segment_model.organizations).to contain_exactly(org, org2)
          end
        end
      end
    end
  end
end
