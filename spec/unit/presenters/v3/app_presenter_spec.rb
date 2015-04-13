require 'spec_helper'
require 'presenters/v3/app_presenter'

module VCAP::CloudController
  describe AppPresenter do
    describe '#present_json' do
      it 'presents the app as json' do
        app = AppModel.make(created_at: Time.at(1), updated_at: Time.at(2), environment_variables: { 'some' => 'stuff' }, desired_state: 'STOPPED')
        process = App.make(space: app.space, instances: 4)
        app.add_process(process)

        json_result = AppPresenter.new.present_json(app)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(app.guid)
        expect(result['name']).to eq(app.name)
        expect(result['desired_state']).to eq(app.desired_state)
        expect(result['environment_variables']).to eq(app.environment_variables)
        expect(result['total_desired_instances']).to eq(4)
        expect(result['created_at']).to eq('1970-01-01T00:00:01Z')
        expect(result['updated_at']).to eq('1970-01-01T00:00:02Z')
        expect(result['_links']).not_to include('desired_droplet')
        expect(result['_links']).to include('start')
        expect(result['_links']).to include('stop')
        expect(result['_links']).to include('assign_current_droplet')
      end

      it 'returns 0 if there are no processes' do
        app = AppModel.make

        json_result = AppPresenter.new.present_json(app)
        result      = MultiJson.load(json_result)

        expect(result['total_desired_instances']).to eq(0)
      end

      it 'returns an empty hash as environment_variables if not present' do
        app = AppModel.make

        json_result = AppPresenter.new.present_json(app)
        result      = MultiJson.load(json_result)

        expect(result['environment_variables']).to eq({})
      end

      it 'includes a link to the droplet if present' do
        app = AppModel.make(desired_droplet_guid: '123')

        json_result = AppPresenter.new.present_json(app)
        result      = MultiJson.load(json_result)

        expect(result['_links']['desired_droplet']['href']).to eq('/v3/droplets/123')
      end

      it 'includes start, stop, and assign_current_droplet links' do
        app = AppModel.make(environment_variables: { 'some' => 'stuff' }, desired_state: 'STOPPED')

        json_result = AppPresenter.new.present_json(app)
        result      = MultiJson.load(json_result)

        expect(result['_links']['start']['method']).to eq('PUT')
        expect(result['_links']['stop']['method']).to eq('PUT')
        expect(result['_links']['assign_current_droplet']['method']).to eq('PUT')
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
      let(:options) { { page: page, per_page: per_page } }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(apps, total_results, PaginationOptions.new(options)) }

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
