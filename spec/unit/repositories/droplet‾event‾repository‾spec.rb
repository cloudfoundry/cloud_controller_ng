require 'spec_helper'
require 'repositories/droplet_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe DropletEventRepository do
      let(:app) { AppModel.make(name: 'popsicle') }
      let(:user) { User.make }
      let(:package) { PackageModel.make(app_guid: app.guid) }
      let(:droplet) { DropletModel.make(app_guid: app.guid, package: package) }
      let(:email) { 'user-email' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: email, user_name: user_name, user_guid: user.guid) }

      describe '#record_create_by_staging' do
        it 'creates a new audit.app.droplet.create event' do
          event = DropletEventRepository.record_create_by_staging(droplet, user_audit_info, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.droplet.create')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)

          metadata = event.metadata
          expect(metadata['droplet_guid']).to eq(droplet.guid)
          expect(metadata['package_guid']).to eq(package.guid)
        end
      end

      describe '#record_create_by_copying' do
        let(:source_droplet_guid) { 'source-droplet-guid' }

        it 'creates a new audit.app.droplet.create event' do
          event = DropletEventRepository.record_create_by_copying(droplet.guid,
                                                                  source_droplet_guid,
                                                                  user_audit_info,
                                                                  app.guid,
                                                                  app.name,
                                                                  package.space.guid,
                                                                  package.space.organization.guid
                                                                 )
          event.reload

          expect(event.type).to eq('audit.app.droplet.create')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)

          metadata = event.metadata
          expect(metadata['droplet_guid']).to eq(droplet.guid)
          expect(metadata['request']).to eq({ 'source_droplet_guid' => source_droplet_guid })
        end
      end

      describe '#record_delete' do
        it 'creates a new audit.app.droplet.delete event' do
          event = DropletEventRepository.record_delete(droplet, user_audit_info, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.droplet.delete')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.metadata['droplet_guid']).to eq(droplet.guid)
        end
      end

      describe '#record_download' do
        it 'creates a new audit.app.droplet.download event' do
          event = DropletEventRepository.record_download(droplet, user_audit_info, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.droplet.download')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.metadata['droplet_guid']).to eq(droplet.guid)
        end
      end
    end
  end
end
