require "spec_helper"

module VCAP::CloudController
  describe 'regression that broke CF', :services, type: :controller do
    let(:space) { Space.make }
    let(:app_obj) { App.make(space: space) }
    let(:service_instance) { ManagedServiceInstance.make(space: space) }
    let!(:service_binding) do
      ServiceBinding.make(
        service_instance: service_instance,
        app: app_obj,
      )
    end
    let(:developer) { make_developer_for_space(space) }

    it 'has the right shape' do
      get "/v2/apps/#{app_obj.guid}/service_bindings?inline-relations-depth=1", nil, json_headers(headers_for(developer))
      last_response.status.should eq(200)

      service_instance_entity = decoded_response.fetch('resources').fetch(0).fetch('entity').
        fetch('service_instance').fetch('entity')
      service_instance_entity.keys.should include(
        'service_plan_url',
        'space_url',
        'service_bindings_url',
      )
    end
  end
end
