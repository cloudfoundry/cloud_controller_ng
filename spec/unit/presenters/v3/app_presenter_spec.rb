require 'spec_helper'
require 'presenters/v3/app_presenter'

module VCAP::CloudController
  describe AppPresenter do
    let(:app) do
      AppModel.make(
      created_at: Time.at(1),
      updated_at: Time.at(2),
      environment_variables: { 'some' => 'stuff' },
      desired_state: 'STOPPED',
    )
    end

    before do
      BuildpackLifecycleDataModel.create(
        buildpack: 'the-happiest-buildpack',
        stack: 'the-happiest-stack',
        app: app
      )
    end

    describe '#present_json' do
      it 'presents the app as json' do
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
        expect(result['links']).not_to include('droplet')
        expect(result['links']).to include('start')
        expect(result['links']).to include('stop')
        expect(result['links']).to include('assign_current_droplet')
        expect(result['lifecycle']['type']).to eq('buildpack')
        expect(result['lifecycle']['data']['stack']).to eq('the-happiest-stack')
        expect(result['lifecycle']['data']['buildpack']).to eq('the-happiest-buildpack')
      end

      context 'if there are no processes' do
        it 'returns 0' do
          json_result = AppPresenter.new.present_json(app)
          result      = MultiJson.load(json_result)

          expect(result['total_desired_instances']).to eq(0)
        end
      end

      context 'if environment_variables are not present' do
        before { app.environment_variables = {} }

        it 'returns an empty hash as environment_variables' do
          json_result = AppPresenter.new.present_json(app)
          result      = MultiJson.load(json_result)

          expect(result['environment_variables']).to eq({})
        end
      end

      context 'links' do
        it 'includes start, stop, and assign_current_droplet links' do
          app.environment_variables = { 'some' => 'stuff' }

          json_result = AppPresenter.new.present_json(app)
          result      = MultiJson.load(json_result)

          expect(result['links']['start']['method']).to eq('PUT')
          expect(result['links']['stop']['method']).to eq('PUT')
          expect(result['links']['assign_current_droplet']['method']).to eq('PUT')
        end

        it 'includes routes links' do
          json_result = AppPresenter.new.present_json(app)
          result      = MultiJson.load(json_result)

          expect(result['links']['routes']['href']).to eq("/v3/apps/#{app.guid}/routes")
        end

        context 'droplets' do
          before do
            app.droplet = DropletModel.make(guid: '123')
          end

          it 'includes a link to the droplet' do
            json_result = AppPresenter.new.present_json(app)
            result      = MultiJson.load(json_result)

            expect(result['links']['droplet']['href']).to eq('/v3/droplets/123')
          end

          it 'includes a link to the droplets if present' do
            DropletModel.make(app_guid: app.guid, state: 'PENDING')

            json_result = AppPresenter.new.present_json(app)
            result      = MultiJson.load(json_result)

            expect(result['links']['droplets']['href']).to eq("/v3/apps/#{app.guid}/droplets")
          end
        end
      end
    end

    describe '#present_json_env' do
      let(:app_model) do
        AppModel.make(
          created_at: Time.at(1),
          updated_at: Time.at(2),
          environment_variables: { 'hello' => 'meow' },
          desired_state: 'STOPPED',
        )
      end

      it 'presents the app environment variables as json' do
        json_result = AppPresenter.new.present_json_env(app_model)
        result      = MultiJson.load(json_result)

        expect(result['environment_variables']).to eq(app_model.environment_variables)
        expect(result['application_env_json']['VCAP_APPLICATION']['name']).to eq(app_model.name)
        expect(result['staging_env_json']).to eq({})
        expect(result['running_env_json']).to eq({})
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { double(:pagination_presenter, present_pagination_hash: 'pagination_stuff') }
      let(:app_model1) { app }
      let(:app_model2) { app }
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
