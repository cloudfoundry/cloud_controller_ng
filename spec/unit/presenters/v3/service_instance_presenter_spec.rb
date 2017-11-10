require 'spec_helper'
require 'presenters/v3/service_instance_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ServiceInstancePresenter do
    let(:presenter) { ServiceInstancePresenter.new(service_instance) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(name: 'denise-db') }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the model as a hash' do
        expect(result[:guid]).to eq(service_instance.guid)
        expect(result[:created_at]).to eq(service_instance.created_at)
        expect(result[:updated_at]).to eq(service_instance.updated_at)
        expect(result[:name]).to eq('denise-db')
      end
    end
  end
end
