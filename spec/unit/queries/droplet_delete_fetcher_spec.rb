require 'spec_helper'
require 'queries/droplet_delete_fetcher'

module VCAP::CloudController
  describe DropletDeleteFetcher do
    describe '#fetch' do
      let!(:droplet) { DropletModel.make }

      subject(:droplet_delete_fetcher) { DropletDeleteFetcher.new }

      it 'returns the droplet, nothing else' do
        expect(droplet_delete_fetcher.fetch(droplet.guid)).to include(droplet)
      end
    end
  end
end
