require 'spec_helper'
require 'queries/isolation_segment_list_fetcher'
require 'messages/isolation_segments_list_message'

module VCAP::CloudController
  RSpec.describe IsolationSegmentListFetcher do
    let(:filters) { {} }
    let(:message) { IsolationSegmentsListMessage.new(filters) }
    subject(:fetcher) { described_class.new(message: message) }

    let!(:isolation_segment_model_1) { VCAP::CloudController::IsolationSegmentModel.make }
    let!(:isolation_segment_model_2) { VCAP::CloudController::IsolationSegmentModel.make(name: 'frank') }
    let!(:isolation_segment_model_3) { VCAP::CloudController::IsolationSegmentModel.make }

    describe '#fetch_all' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all isolation segments' do
        isolation_segment_models = fetcher.fetch_all.all

        expect(isolation_segment_models).to match_array([isolation_segment_model_1, isolation_segment_model_2, isolation_segment_model_3])
      end

      context 'filters' do
        context 'by guids' do
          let(:filters) { { guids: [isolation_segment_model_1.guid] } }

          it 'filters by guids' do
            isolation_segment_models = fetcher.fetch_all.all

            expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1)
          end
        end

        context 'by names' do
          let(:filters) { { names: [isolation_segment_model_2.name.capitalize, isolation_segment_model_3.name] } }

          it 'filters by names and ignores case' do
            isolation_segment_models = fetcher.fetch_all.all

            expect(isolation_segment_models).to contain_exactly(isolation_segment_model_2, isolation_segment_model_3)
          end
        end
      end
    end

    describe '#fetch_for_spaces' do
      let(:space1) { VCAP::CloudController::Space.make(isolation_segment_guid: isolation_segment_model_1.guid) }
      let(:space2) { VCAP::CloudController::Space.make(isolation_segment_guid: isolation_segment_model_2.guid) }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(space_guids: [])
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'fetches only those isolation segments associated with the specified spaces' do
        isolation_segment_models = fetcher.fetch_for_spaces(space_guids: [space1.guid, space2.guid]).all

        expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1, isolation_segment_model_2)
      end

      it 'returns no isolation segments when the list of space guids is empty' do
        isolation_segment_models = fetcher.fetch_for_spaces(space_guids: []).all

        expect(isolation_segment_models).to be_empty
      end

      context 'filtering by names' do
        let(:filters) { { names: [isolation_segment_model_2.name.capitalize, isolation_segment_model_3.name] } }

        it 'filters by names and ignores case' do
          isolation_segment_models = fetcher.fetch_for_spaces(space_guids: [space1.guid, space2.guid]).all

          expect(isolation_segment_models).to contain_exactly(isolation_segment_model_2)
        end
      end

      context 'filtering by guids' do
        let(:filters) { { guids: [isolation_segment_model_1.guid] } }

        it 'filters by guids' do
          isolation_segment_models = fetcher.fetch_for_spaces(space_guids: [space1.guid, space2.guid]).all

          expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1)
        end
      end
    end
  end
end
