require 'spec_helper'
require 'presenters/v3/droplet_presenter'

module VCAP::CloudController
  describe DropletPresenter do
    let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }
    let(:droplet) do
      DropletModel.make(
        state:                  DropletModel::STAGED_STATE,
        buildpack_guid:         'buildpack-guid',
        buildpack:              'actual-buildpack',
        error:         'example error',
        process_types: { 'web' => 'npm start', 'worker' => 'start worker' },
        environment_variables:  { 'elastic' => 'runtime' },
        memory_limit: 234,
        disk_limit: 934,
        stack_name: Stack.default.name,
        execution_metadata: 'black-box-string'
      )
    end

    before do
      droplet.lifecycle_data.buildpack = 'the-happiest-buildpack'
      droplet.lifecycle_data.stack    = 'the-happiest-stack'
    end

    describe '#present_json' do
      it 'presents the droplet as json' do
        json_result = DropletPresenter.new.present_json(droplet)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(droplet.guid)
        expect(result['state']).to eq(droplet.state)
        expect(result['error']).to eq(droplet.error)

        expect(result['lifecycle']['type']).to eq('buildpack')
        expect(result['lifecycle']['data']['stack']).to eq('the-happiest-stack')
        expect(result['lifecycle']['data']['buildpack']).to eq('the-happiest-buildpack')
        expect(result['environment_variables']).to eq(droplet.environment_variables)
        expect(result['memory_limit']).to eq(234)
        expect(result['disk_limit']).to eq(934)
        expect(result['result']['hash']).to eq({ 'type' => 'sha1', 'value' => nil })
        expect(result['result']['buildpack']).to eq('actual-buildpack')
        expect(result['result']['stack']).to eq(Stack.default.name)
        expect(result['result']['process_types']).to eq({ 'web' => 'npm start', 'worker' => 'start worker' })
        expect(result['result']['execution_metadata']).to eq('black-box-string')

        expect(result['created_at']).to match(iso8601)
        expect(result['updated_at']).to match(iso8601)
        expect(result['links']).to include('self')
        expect(result['links']['self']['href']).to eq("/v3/droplets/#{droplet.guid}")
        expect(result['links']).to include('package')
        expect(result['links']['package']['href']).to eq("/v3/packages/#{droplet.package_guid}")
        expect(result['links']['buildpack']['href']).to eq("/v2/buildpacks/#{droplet.buildpack_guid}")
        expect(result['links']['app']['href']).to eq("/v3/apps/#{droplet.app_guid}")
        expect(result['links']['assign_current_droplet']['href']).to eq("/v3/apps/#{droplet.app_guid}/current_droplet")
        expect(result['links']['assign_current_droplet']['method']).to eq('PUT')
      end
    end

    context 'when the buildpack_guid is not present' do
      let(:droplet) { DropletModel.make }

      before do
        droplet.lifecycle_data.buildpack = nil
      end

      it 'does NOT include a link to upload' do
        json_result = DropletPresenter.new.present_json(droplet)
        result      = MultiJson.load(json_result)

        expect(result['links']['buildpack']).to be_nil
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { instance_double(PaginationPresenter) }
      let(:droplet1) { droplet }
      let(:droplet2) { droplet }
      let(:droplets) { [droplet1, droplet2] }
      let(:presenter) { DropletPresenter.new(pagination_presenter) }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:options) { { page: page, per_page: per_page } }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(droplets, total_results, PaginationOptions.new(options)) }
      let(:params) { { 'states' => ['foo'] } }
      let(:base_url) { 'bazooka' }

      before do
        allow(pagination_presenter).to receive(:present_pagination_hash) do |_, url|
          "pagination-#{url}"
        end
      end

      it 'presents the droplets as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, base_url, params)
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |droplet_json| droplet_json['guid'] }
        expect(guids).to eq([droplet1.guid, droplet2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result, base_url, params)
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination-bazooka')
      end

      it 'passes the parameters to the pagination presenter' do
        expect(pagination_presenter).to receive(:present_pagination_hash).with(paginated_result, base_url, params)

        presenter.present_json_list(paginated_result, base_url, params)
      end
    end
  end
end
