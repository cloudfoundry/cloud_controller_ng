require 'spec_helper'
require 'fetchers/droplet_fetcher'

module VCAP::CloudController
  RSpec.describe DropletFetcher do
    describe '#fetch' do
      let!(:droplet) { DropletModel.make }
      let(:space) { droplet.space }

      subject(:droplet_delete_fetcher) { DropletFetcher.new }

      it 'returns the droplet and space' do
        expect(droplet_delete_fetcher.fetch(droplet.guid)).to include(droplet, space)
      end
    end
  end
end
