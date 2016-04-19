require 'spec_helper'
require 'repositories/runtime/droplet_event_repository'

module VCAP::CloudController
  module Repositories::Runtime
    describe DropletEventRepository do
      describe '#record_dropet_create_by_staging' do
        let(:app) { AppModel.make }
        let(:user) { User.make }
        let(:package) { PackageModel.make(app_guid: app.guid) }
        let(:droplet) { DropletModel.make(app_guid: app.guid) }
        let(:email) { 'user-email' }
        let(:request_attrs) do
          {
            'app_guid' => 'app-guid',
            'type'     => 'docker',
            'url'      => 'dockerurl.example.com'
          }
        end

        it 'creates a new audit.app.droplet.create event' do
          event = DropletEventRepository.record_dropet_create_by_staging(droplet, user, email, request_attrs, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.droplet.create')

          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)

          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq(app.name)

          expect(event.space_guid).to eq(app.space.guid)

          request = event.metadata.fetch('request')
          expect(request).to eq(request_attrs)
        end
      end
    end
  end
end
