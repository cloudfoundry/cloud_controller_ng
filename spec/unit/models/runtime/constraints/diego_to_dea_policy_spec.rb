require 'spec_helper'

RSpec.describe DiegoToDeaPolicy do
  let(:app_hash) do
    {
      name: 'test',
      diego: true,
      ports: [8081, 8082]
    }
  end
  let(:app) { VCAP::CloudController::AppFactory.make(app_hash) }
  let(:route) { VCAP::CloudController::Route.make(host: 'host', space: app.space) }
  let(:route2) { VCAP::CloudController::Route.make(host: 'host', space: app.space) }
  let(:validator) { DiegoToDeaPolicy.new(app, true) }

  context 'app with no route mappings' do
    before do
      app.diego = false
    end

    it 'returns no errors' do
      expect(app.valid?).to eq(true)
    end
  end

  context 'app with multiple ports but only one port mapped' do
    let!(:route_mapping_1) { VCAP::CloudController::RouteMapping.make(app: app, route: route) }
    let!(:route_mapping_2) { VCAP::CloudController::RouteMapping.make(app: app, route: route2) }

    before do
      app.diego = false
    end

    it 'returns no errors' do
      expect(app.valid?).to eq(true)
    end
  end

  context 'app with multiple route mappings' do
    let!(:route_mapping_1) { VCAP::CloudController::RouteMapping.make(app: app, route: route) }
    let!(:route_mapping_2) { VCAP::CloudController::RouteMapping.make(app: app, route: route2) }

    before do
      route_mapping_2.app_port = 8082
      app.diego = false
    end

    it 'registers error when app is mapped to more than one port' do
      expect(validator).to validate_with_error(app, :diego_to_dea, 'Multiple app ports not allowed')
    end
  end
end
