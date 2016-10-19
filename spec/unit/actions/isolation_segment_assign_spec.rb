require 'spec_helper'
require 'isolation_segment_assign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentAssign do
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:org) { Organization.make }

    context 'when the segment is not already assigned to the org' do
      it 'adds a segment to the allowed list' do
        subject.assign(isolation_segment_model, org)
        expect(org.isolation_segment_models).to include(isolation_segment_model)
      end

      it 'sets the first isolation segment added as the default' do
        subject.assign(isolation_segment_model, org)
        expect(org.isolation_segment_model).to eq(isolation_segment_model)
      end
    end

    context 'and the segment is already assigned to the org' do
      before do
        subject.assign(isolation_segment_model, org)
      end

      it 'is idempotent' do
        subject.assign(isolation_segment_model, org)
        expect(org.isolation_segment_models).to eq([isolation_segment_model])
      end
    end

    context 'and other isolation segments are already assigned to the org' do
      let(:isolation_segment_model2) { IsolationSegmentModel.make }

      before do
        subject.assign(isolation_segment_model, org)
      end

      it 'adds the segment to the allowed list' do
        subject.assign(isolation_segment_model2, org)
        expect(org.isolation_segment_models).to match_array([
          isolation_segment_model,
          isolation_segment_model2
        ])
      end

      it 'does not change the default isolation segment for the org' do
        subject.assign(isolation_segment_model2, org)
        expect(org.isolation_segment_model).to eq(isolation_segment_model)
      end
    end
  end
end
