require 'spec_helper'
require 'queries/service_binding_create_fetcher'

module VCAP::CloudController
  describe ServiceBindingCreateFetcher do
    describe '#fetch' do
      let(:app_model) { AppModel.make(name: 'my-app') }
      let(:service_instance) { ServiceInstance.make(name: 'my-service', space_guid: app_model.space.guid) }

      it 'returns the app and service instance' do
        fetched_app, fetched_instance = ServiceBindingCreateFetcher.new.fetch(app_model.guid, service_instance.guid)

        expect(fetched_app.name).to eq(app_model.name)
        expect(fetched_instance.name).to eq(service_instance.name)
      end
    end
  end
end
