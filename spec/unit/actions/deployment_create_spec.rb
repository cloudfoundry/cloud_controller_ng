require 'spec_helper'
require 'actions/deployment_create'

module VCAP::CloudController
  RSpec.describe DeploymentCreate do
    let(:app) { VCAP::CloudController::AppModel.make(droplet: droplet) }
    let!(:web_process) { VCAP::CloudController::ProcessModel.make(app: app) }
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    let!(:route1) { VCAP::CloudController::Route.make(space: app.space) }
    let!(:route_mapping1) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route1, process_type: web_process.type) }
    let!(:route2) { VCAP::CloudController::Route.make(space: app.space) }
    let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route2, process_type: web_process.type) }
    let(:user_audit_info) { instance_double(UserAuditInfo, user_guid: nil) }

    describe '#create' do
      it 'creates a deployment' do
        deployment = nil

        expect {
          deployment = DeploymentCreate.create(app: app, user_audit_info: user_audit_info)
        }.to change { DeploymentModel.count }.by(1)

        expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
        expect(deployment.app_guid).to eq(app.guid)
        expect(deployment.droplet_guid).to eq(droplet.guid)
      end

      it 'creates a process of web-deployment-guid type with the same characteristics as the existing web process' do
        deployment = DeploymentCreate.create(app: app, user_audit_info: user_audit_info)

        new_process = app.processes.select { |p| p.type == "web-deployment-#{deployment.guid}" }.first
        expect(new_process.state).to eq ProcessModel::STARTED
        expect(new_process.command).to eq(web_process.command)
        expect(new_process.memory).to eq(web_process.memory)
        expect(new_process.file_descriptors).to eq(web_process.file_descriptors)
        expect(new_process.disk_quota).to eq(web_process.disk_quota)
        expect(new_process.metadata).to eq(web_process.metadata)
        expect(new_process.detected_buildpack).to eq(web_process.detected_buildpack)
        expect(new_process.health_check_timeout).to eq(web_process.health_check_timeout)
        expect(new_process.health_check_type).to eq(web_process.health_check_type)
        expect(new_process.health_check_http_endpoint).to eq(web_process.health_check_http_endpoint)
        expect(new_process.health_check_invocation_timeout).to eq(web_process.health_check_invocation_timeout)
        expect(new_process.enable_ssh).to eq(web_process.enable_ssh)
        expect(new_process.ports).to eq(web_process.ports)
      end

      it 'creates route mappings for each route mapped to the existing web process' do
        deployment = DeploymentCreate.create(app: app, user_audit_info: user_audit_info)
        new_process = app.processes.select { |p| p.type == "web-deployment-#{deployment.guid}" }.first

        expect(new_process.routes).to contain_exactly(route1, route2)
      end

      context 'when the app does not have a droplet set' do
        let(:app) { VCAP::CloudController::AppModel.make }

        it 'sets the droplet on the deployment to nil' do
          deployment = DeploymentCreate.create(app: app, user_audit_info: user_audit_info)

          expect(deployment.app).to eq(app)
          expect(deployment.droplet).to be_nil
        end
      end
    end
  end
end
