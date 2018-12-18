require 'spec_helper'
require 'fetchers/droplet_fetcher'

module VCAP::CloudController
  RSpec.describe DropletFetcher do
    describe '#fetch' do
      let!(:droplet) { DropletModel.make }
      let(:space) { droplet.space }
      let(:org) { space.organization }

      subject(:droplet_delete_fetcher) { DropletFetcher.new }

      it 'returns the droplet, space, and org' do
        expect(droplet_delete_fetcher.fetch(droplet.guid)).to include(droplet, space, org)
      end
    end
  end
end
