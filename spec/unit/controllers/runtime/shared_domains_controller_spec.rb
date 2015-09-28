require 'spec_helper'

module VCAP::CloudController
  describe SharedDomainsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          router_group_guid: { type: 'string', required: false }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          router_group_guid: { type: 'string' }
        })
      end
    end
  end
end
