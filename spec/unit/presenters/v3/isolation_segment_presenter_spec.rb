require 'spec_helper'
require 'presenters/v3/isolation_segment_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe IsolationSegmentPresenter do
    let(:label) { VCAP::CloudController::IsolationSegmentModel.make }

    describe '#to_hash' do
      let(:result) { IsolationSegmentPresenter.new(label).to_hash }

      it 'presents the label as json' do
        expect(result[:guid]).to eq(label.guid)
        expect(result[:name]).to eq(label.name)
        expect(result[:created_at]).to eq(label.created_at)
        expect(result[:updated_at]).to eq(label.updated_at)
      end
    end
  end
end
