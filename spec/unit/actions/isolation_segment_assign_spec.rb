require 'spec_helper'
require 'isolation_segment_assign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentAssign do
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:org) { Organization.make }
    let(:org2) { Organization.make }

    it 'sorts the organizations passed in for assignment' do
      org.update(guid: 'b')
      org2.update(guid: 'a')

      org.reload
      org2.reload

      expect(isolation_segment_model).to receive(:add_organization).with(org2).ordered
      expect(isolation_segment_model).to receive(:add_organization).with(org).ordered
      subject.assign(isolation_segment_model, [org, org2])
    end

    context 'when an isolation segment is not assigned to any orgs' do
      it 'adds the organization to the isolation segment' do
        subject.assign(isolation_segment_model, [org, org2])
        expect(isolation_segment_model.organizations).to include(org, org2)
      end

      it 'does not set the default isolation segment for the org' do
        subject.assign(isolation_segment_model, [org])
        expect(org.default_isolation_segment_model).to be_nil
      end
    end

    context 'and the segment is already assigned to the org' do
      before do
        subject.assign(isolation_segment_model, [org])
      end

      it 'is idempotent' do
        subject.assign(isolation_segment_model, [org])
        expect(org.isolation_segment_models).to eq([isolation_segment_model])
      end
    end

    context 'and other isolation segments are already assigned to the org' do
      let(:isolation_segment_model2) { IsolationSegmentModel.make }

      before do
        subject.assign(isolation_segment_model, [org])
      end

      it 'adds the segment to the allowed list' do
        subject.assign(isolation_segment_model2, [org])
        expect(org.isolation_segment_models).to match_array([
          isolation_segment_model,
          isolation_segment_model2
        ])
      end
    end

    context 'when assigning the shared isolation segment' do
      let(:shared_segment) { IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID) }

      context 'and the org does not already have a default isolation segment set' do
        it 'sets the shared segment as the organizational default' do
          subject.assign(shared_segment, [org])
          expect(org.default_isolation_segment_model).to eq(shared_segment)
        end
      end

      context 'and the org has another isolation segment set as the default' do
        before do
          subject.assign(isolation_segment_model, [org])
          org.update(default_isolation_segment_model: isolation_segment_model)
          org.reload
        end

        it 'does not change the default isolation segment' do
          subject.assign(shared_segment, [org])
          expect(org.default_isolation_segment_model).to eq(isolation_segment_model)
        end
      end
    end
  end
end
