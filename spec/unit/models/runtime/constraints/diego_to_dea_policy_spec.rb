require 'spec_helper'

RSpec.describe DiegoToDeaPolicy do
  let(:app_hash) do
    {
      name: 'test',
      diego: true,
      ports: [8081, 8082]
    }
  end
  let(:process) { VCAP::CloudController::ProcessModelFactory.make(app_hash) }
  let(:route) { VCAP::CloudController::Route.make(host: 'host', space: process.space) }
  let(:route2) { VCAP::CloudController::Route.make(host: 'host', space: process.space) }
  let(:validator) { DiegoToDeaPolicy.new(process, true) }

  context 'app with no route mappings' do
    before do
      process.diego = false
    end

    it 'returns no errors' do
      expect(process.valid?).to eq(true)
    end
  end

  context 'app with multiple ports but only one port mapped' do
    let!(:route_mapping_1) { VCAP::CloudController::RouteMappingModel.make(app: process.app, process_type: process.type, route: route) }
    let!(:route_mapping_2) { VCAP::CloudController::RouteMappingModel.make(app: process.app, process_type: process.type, route: route2) }

    before do
      process.diego = false
    end

    it 'returns no errors' do
      expect(process.valid?).to eq(true)
    end
  end

  context 'app with multiple route mappings' do
    let!(:route_mapping_1) { VCAP::CloudController::RouteMappingModel.make(app: process.app, process_type: process.type, route: route) }
    let!(:route_mapping_2) { VCAP::CloudController::RouteMappingModel.make(app: process.app, process_type: process.type, route: route2) }

    before do
      route_mapping_2.update(app_port: 8082)
      process.diego = false
    end

    it 'registers error when app is mapped to more than one port' do
      expect(validator).to validate_with_error(process, :diego_to_dea, 'Multiple app ports not allowed')
    end
  end

  context 'docker app' do
    before do
      process.app.buildpack_lifecycle_data = nil
      process.diego = false
    end

    it 'registers error when app is a docker app and cannot run on DEAs' do
      expect(validator).to validate_with_error(process, :docker_to_dea, 'Cannot change docker app to DEAs')
    end
  end
end
