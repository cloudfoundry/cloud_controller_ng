require 'spec_helper'
require 'repositories/deployment_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe DeploymentEventRepository do
      let(:app) { AppModel.make(name: 'popsicle') }
      let(:user) { User.make }
      let(:droplet) { DropletModel.make }
      let(:deployment) { DeploymentModel.make(app_guid: app.guid) }
      let(:email) { 'user-email' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: email, user_name: user_name, user_guid: user.guid) }
      let(:params) do
        { 'foo' => 'bar ' }
      end
      let(:type) { 'rollback' }

      describe '#record_create_deployment' do
        context 'when a droplet is associated with the deployment' do
          let(:deployment) { DeploymentModel.make(app_guid: app.guid, droplet_guid: droplet.guid) }
          it 'creates a new audit.app.deployment.create event' do
            event = DeploymentEventRepository.record_create(deployment, droplet, user_audit_info, app.name,
              app.space.guid, app.space.organization.guid, params, type)
            event.reload

            expect(event.type).to eq('audit.app.deployment.create')
            expect(event.actor).to eq(user.guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(email)
            expect(event.actor_username).to eq(user_name)
            expect(event.actee).to eq(deployment.app_guid)
            expect(event.actee_type).to eq('app')
            expect(event.actee_name).to eq('popsicle')
            expect(event.space_guid).to eq(app.space.guid)

            metadata = event.metadata
            expect(metadata['deployment_guid']).to eq(deployment.guid)
            expect(metadata['droplet_guid']).to eq(droplet.guid)
            expect(metadata['request']).to eq(params)
            expect(metadata['type']).to eq(type)
          end
        end

        context 'when no droplet is associated with the deployment' do
          let(:deployment) { DeploymentModel.make(app_guid: app.guid) }
          it 'creates a new audit.app.deployment.create event' do
            event = DeploymentEventRepository.record_create(deployment, nil, user_audit_info, app.name,
              app.space.guid, app.space.organization.guid, params, type)
            event.reload

            expect(event.type).to eq('audit.app.deployment.create')
            expect(event.actor).to eq(user.guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(email)
            expect(event.actor_username).to eq(user_name)
            expect(event.actee).to eq(deployment.app_guid)
            expect(event.actee_type).to eq('app')
            expect(event.actee_name).to eq('popsicle')
            expect(event.space_guid).to eq(app.space.guid)

            metadata = event.metadata
            expect(metadata['deployment_guid']).to eq(deployment.guid)
            expect(metadata['droplet_guid']).to be_nil
            expect(metadata['request']).to eq(params)
            expect(metadata['type']).to eq(type)
          end
        end
      end

      describe 'record_cancel_deployment' do
        let(:deployment) { DeploymentModel.make(app_guid: app.guid) }
        it 'creates a new audit.app.deployment.cancel event' do
          event = DeploymentEventRepository.record_cancel(deployment, droplet, user_audit_info, app.name,
            app.space.guid, app.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.deployment.cancel')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(deployment.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.timestamp).not_to be_nil
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.organization.guid)

          metadata = event.metadata
          expect(metadata['deployment_guid']).to eq(deployment.guid)
          expect(metadata['droplet_guid']).to eq(droplet.guid)
        end
      end
    end
  end
end
