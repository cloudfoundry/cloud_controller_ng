require 'spec_helper'
require 'presenters/v3/droplet_presenter'

module VCAP::CloudController
  describe DropletPresenter do
    describe '#present_json' do
      it 'presents the droplet as json' do
        droplet = DropletModel.make(
          state:                  DropletModel::STAGED_STATE,
          buildpack_guid:         'a-buildpack',
          error:         'example error',
          procfile: 'web: npm start',
          environment_variables:  { 'elastic' => 'runtime' },
          created_at: Time.at(1),
          updated_at: Time.at(2),
        )

        json_result = DropletPresenter.new.present_json(droplet)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(droplet.guid)
        expect(result['state']).to eq(droplet.state)
        expect(result['hash']).to eq({ 'type' => 'sha1', 'value' => nil })
        expect(result['buildpack']).to eq(droplet.buildpack)
        expect(result['error']).to eq(droplet.error)
        expect(result['procfile']).to eq(droplet.procfile)
        expect(result['environment_variables']).to eq(droplet.environment_variables)
        expect(result['created_at']).to eq('1970-01-01T00:00:01Z')
        expect(result['updated_at']).to eq('1970-01-01T00:00:02Z')
        expect(result['_links']).to include('self')
        expect(result['_links']['self']['href']).to eq("/v3/droplets/#{droplet.guid}")
        expect(result['_links']).to include('package')
        expect(result['_links']['package']['href']).to eq("/v3/packages/#{droplet.package_guid}")
        expect(result['_links']['buildpack']['href']).to eq("/v2/buildpacks/#{droplet.buildpack_guid}")
        expect(result['_links']['app']['href']).to eq("/v3/apps/#{droplet.app_guid}")
        expect(result['_links']['assign_current_droplet']['href']).to eq("/v3/apps/#{droplet.app_guid}/current_droplet")
        expect(result['_links']['assign_current_droplet']['method']).to eq('PUT')
      end
    end

    context 'when the droplet is not in the STAGED state' do
      it 'does not include the assign_current_droplet link' do
        droplet = DropletModel.make(
          state:                  DropletModel::STAGING_STATE,
          buildpack_guid:         'a-buildpack',
          error:         'example error',
          procfile: 'web: npm start',
          environment_variables:  { 'elastic' => 'runtime' },
          created_at: Time.at(1),
          updated_at: Time.at(2),
        )

        json_result = DropletPresenter.new.present_json(droplet)
        result      = MultiJson.load(json_result)

        expect(result['_links']['assign_current_droplet']).to be_nil
      end
    end

    context 'when the buildpack_guid is not present' do
      let(:droplet) { DropletModel.make }

      it 'does NOT include a link to upload' do
        json_result = DropletPresenter.new.present_json(droplet)
        result      = MultiJson.load(json_result)

        expect(result['_links']['buildpack']).to be_nil
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { double(:pagination_presenter) }
      let(:droplet1) { DropletModel.make }
      let(:droplet2) { DropletModel.make }
      let(:droplets) { [droplet1, droplet2] }
      let(:presenter) { DropletPresenter.new(pagination_presenter) }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:options) { { page: page, per_page: per_page } }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(droplets, total_results, PaginationOptions.new(options)) }
      before do
        allow(pagination_presenter).to receive(:present_pagination_hash) do |_, url|
          "pagination-#{url}"
        end
      end

      it 'presents the droplets as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, 'potato')
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |droplet_json| droplet_json['guid'] }
        expect(guids).to eq([droplet1.guid, droplet2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result, 'bazooka')
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination-bazooka')
      end
    end
  end
end
