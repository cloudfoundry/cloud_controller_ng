require 'spec_helper'
require 'presenters/v3/app_presenter'

module VCAP::CloudController
  describe AppPresenter do
    describe '#present_json' do
      it 'presents the app as json' do
        app = AppModel.make

        json_result = AppPresenter.new.present_json(app)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(app.guid)
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { double(:pagination_presenter, present_pagination_hash: 'pagination_stuff') }
      let(:app_model1) { AppModel.make }
      let(:app_model2) { AppModel.make }
      let(:apps) { [app_model1, app_model2] }
      let(:presenter) { AppPresenter.new(pagination_presenter) }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(apps, total_results, PaginationOptions.new(page, per_page)) }

      it 'presents the apps as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |app_json| app_json['guid'] }
        expect(guids).to eq([app_model1.guid, app_model2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination_stuff')
      end
    end
  end
end
