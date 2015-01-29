require 'spec_helper'
require 'presenters/v3/droplet_presenter'

module VCAP::CloudController
  describe DropletPresenter do
    describe '#present_json' do
      it 'presents the droplet as json' do
        droplet = DropletModel.make(
          state:             DropletModel::STAGED_STATE,
          buildpack_guid:    'a-buildpack',
          buildpack_git_url: 'http://git.url', droplet_hash: '1234')

        json_result = DropletPresenter.new.present_json(droplet)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(droplet.guid)
        expect(result['state']).to eq(droplet.state)
        expect(result['hash']).to eq(droplet.droplet_hash)
        expect(result['buildpack_guid']).to eq(droplet.buildpack_guid)
        expect(result['buildpack_git_url']).to eq(droplet.buildpack_git_url)
        expect(result['created_at']).to eq(droplet.created_at.as_json)
        expect(result['_links']).to include('self')
        expect(result['_links']['self']['href']).to eq("/v3/droplets/#{droplet.guid}")
        expect(result['_links']).to include('package')
        expect(result['_links']['package']['href']).to eq("/v3/packages/#{droplet.package_guid}")
      end
    end
  end
end
