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
      let(:app_model1) { AppModel.make }
      let(:app_model2) { AppModel.make }
      let(:apps) { [app_model1, app_model2] }
      let(:presenter) { AppPresenter.new }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(apps, total_results, page, per_page) }

      it 'presents the apps as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |app_json| app_json['guid'] }
        expect(guids).to eq([app_model1.guid, app_model2.guid])
      end

      it 'includes total_results' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        tr = result['pagination']['total_results']
        expect(tr).to eq(total_results)
      end

      it 'includes first_url' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        first_url = result['pagination']['first']['href']
        expect(first_url).to eq("/v3/apps?page=1&per_page=#{per_page}")
      end

      it 'includes last_url' do
        json_result = presenter.present_json_list(paginated_result)
        result      = MultiJson.load(json_result)

        last_url = result['pagination']['last']['href']
        expect(last_url).to eq("/v3/apps?page=2&per_page=#{per_page}")
      end

      it 'sets first and last page to 1 if there is 1 page' do
        paginated_result = PaginatedResult.new([], 0, page, per_page)
        json_result      = presenter.present_json_list(paginated_result)
        result           = MultiJson.load(json_result)

        last_url  = result['pagination']['last']['href']
        first_url = result['pagination']['first']['href']
        expect(last_url).to eq("/v3/apps?page=1&per_page=#{per_page}")
        expect(first_url).to eq("/v3/apps?page=1&per_page=#{per_page}")
      end

      context 'when on the first page' do
        let(:page) { 1 }

        it 'sets previous_url to nil' do
          json_result = presenter.present_json_list(paginated_result)
          result      = MultiJson.load(json_result)

          previous_url = result['pagination']['previous']
          expect(previous_url).to be_nil
        end
      end

      context 'when NOT on the first page' do
        let(:page) { 2 }

        it 'includes previous_url' do
          json_result = presenter.present_json_list(paginated_result)
          result      = MultiJson.load(json_result)

          previous_url = result['pagination']['previous']['href']
          expect(previous_url).to eq("/v3/apps?page=1&per_page=#{per_page}")
        end
      end

      context 'when on the last page' do
        let(:page) { apps.length }
        let(:per_page) { 1 }

        it 'sets next_url to nil' do
          json_result = presenter.present_json_list(paginated_result)
          result      = MultiJson.load(json_result)

          next_url = result['pagination']['next']
          expect(next_url).to be_nil
        end
      end

      context 'when NOT on the last page' do
        let(:page) { 1 }
        let(:per_page) { 1 }

        it 'includes next_url' do
          json_result = presenter.present_json_list(paginated_result)
          result      = MultiJson.load(json_result)

          next_url = result['pagination']['next']['href']
          expect(next_url).to eq("/v3/apps?page=2&per_page=#{per_page}")
        end
      end
    end
  end
end
