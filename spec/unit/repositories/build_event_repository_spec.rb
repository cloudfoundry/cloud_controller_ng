require 'spec_helper'
require 'repositories/build_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe BuildEventRepository do
      let(:app) { AppModel.make(name: 'popsicle') }
      let(:user) { User.make }
      let(:package) { PackageModel.make(app_guid: app.guid) }
      let(:build) { BuildModel.make(app_guid: app.guid, package: package) }
      let(:email) { 'user-email' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: email, user_name: user_name, user_guid: user.guid) }

      describe '#record_create_by_staging' do
        it 'creates a new audit.app.build.create event' do
          event = BuildEventRepository.record_build_create(build, user_audit_info, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.build.create')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(build.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)

          metadata = event.metadata
          expect(metadata['build_guid']).to eq(build.guid)
          expect(metadata['package_guid']).to eq(package.guid)
        end
      end
    end
  end
end
