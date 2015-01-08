require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  describe ProcessPresenter do
    describe '#present_json' do
      it 'presents the process as json' do
        process_model = AppFactory.make
        process       = AppProcess.new(process_model)

        json_result = ProcessPresenter.new.present_json(process)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(process.guid)
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { double(:pagination_presenter, present_pagination_hash: 'pagination_stuff') }
      let(:process1) { AppFactory.make }
      let(:process2) { AppFactory.make }
      let(:processes) { [process1, process2] }
      let(:presenter) { ProcessPresenter.new(pagination_presenter) }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(processes, total_results, page, per_page) }

      it 'presents the processes as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |app_json| app_json['guid'] }
        expect(guids).to eq([process1.guid, process2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination_stuff')
      end
    end
  end
end
