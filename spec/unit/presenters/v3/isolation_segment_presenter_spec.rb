require 'spec_helper'
require 'presenters/v3/isolation_segment_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe IsolationSegmentPresenter do
    let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }

    describe '#to_hash' do
      let(:result) { IsolationSegmentPresenter.new(isolation_segment).to_hash }

      it 'presents the isolation_segment as json' do
        links = {
          self: { href: "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" },
          organizations: { href: "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}/organizations" },
        }

        expect(result[:guid]).to eq(isolation_segment.guid)
        expect(result[:name]).to eq(isolation_segment.name)
        expect(result[:created_at]).to eq(isolation_segment.created_at)
        expect(result[:updated_at]).to eq(isolation_segment.updated_at)
        expect(result[:links]).to eq(links)
      end
    end
  end
end
