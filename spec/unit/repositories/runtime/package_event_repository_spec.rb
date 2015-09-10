require 'spec_helper'
require 'repositories/runtime/package_event_repository'

module VCAP::CloudController
  module Repositories::Runtime
    describe PackageEventRepository do
      describe '#record_app_add_package' do
        let(:app) { AppModel.make }
        let(:user) { User.make }
        let(:package) { PackageModel.make(app_guid: app.guid) }
        let(:email) { 'user-email' }
        let(:request_attrs) do
          {
            'app_guid' => 'app-guid',
            'type'     => 'docker',
            'url'      => 'dockerurl.example.com'
          }
        end

        it 'creates a new audit.app.start event' do
          event = PackageEventRepository.record_app_add_package(package, user, email, request_attrs)
          event.reload

          expect(event.type).to eq('audit.app.add_package')

          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)

          expect(event.actee).to eq(package.guid)
          expect(event.actee_type).to eq('package')
          expect(event.actee_name).to eq('')

          expect(event.space).to eq(app.space)
          expect(event.space_guid).to eq(app.space.guid)

          request = event.metadata.fetch('request')
          expect(request).to eq(request_attrs)
        end
      end
    end
  end
end
