require 'spec_helper'
require 'repositories/package_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe PackageEventRepository do
      let(:app) { AppModel.make(name: 'potato') }
      let(:user_guid) { 'user_guid' }
      let(:package) { PackageModel.make(app_guid: app.guid) }
      let(:email) { 'user-email' }

      describe '#record_app_package_create' do
        context 'when request attrs include data' do
          let(:request_attrs) do
            { 'app_guid' => app.guid,
              'type' => 'docker',
              'data' => 'some data'
            }
          end

          it 'creates a new audit.app.start event' do
            event = PackageEventRepository.record_app_package_create(package, user_guid, email, request_attrs)
            event.reload

            expect(event.type).to eq('audit.app.package.create')
            expect(event.actor).to eq(user_guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(email)
            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('v3-app')
            expect(event.actee_name).to eq('potato')
            expect(event.space_guid).to eq(app.space.guid)
            expect(event.organization_guid).to eq(app.space.organization.guid)

            request = event.metadata.fetch('request')
            expect(request).to eq({ 'type' => 'docker',
                                    'data' => 'some data' })

            package_guid = event.metadata.fetch('package_guid')
            expect(package_guid).to eq(package.guid)
          end
        end

        context 'when request attrs do not include data' do
          let(:request_attrs) { { 'app_guid' => app.guid, 'type' => 'bits' } }

          it 'creates a new audit.app.start event' do
            event = PackageEventRepository.record_app_package_create(package, user_guid, email, request_attrs)
            event.reload

            expect(event.type).to eq('audit.app.package.create')
            expect(event.actor).to eq(user_guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(email)
            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('v3-app')
            expect(event.actee_name).to eq('potato')
            expect(event.space_guid).to eq(app.space.guid)
            expect(event.organization_guid).to eq(app.space.organization.guid)

            request = event.metadata.fetch('request')
            expect(request).to eq({ 'type' => 'bits' })

            package_guid = event.metadata.fetch('package_guid')
            expect(package_guid).to eq(package.guid)
          end
        end
      end

      describe 'record_app_package_copy' do
        let(:source_package_guid) { '123-some-guid' }

        it 'creates a new audit.app.copy event' do
          event = PackageEventRepository.record_app_package_copy(package, user_guid, email, source_package_guid)
          event.reload

          expect(event.type).to eq('audit.app.package.create')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          request = event.metadata.fetch('request')
          expect(request).to eq({ 'source_package_guid' => source_package_guid })

          package_guid = event.metadata.fetch('package_guid')
          expect(package_guid).to eq(package.guid)
        end
      end

      describe 'record_app_package_upload' do
        it 'creates a new upload event' do
          event = PackageEventRepository.record_app_package_upload(package, user_guid, email)
          event.reload

          expect(event.type).to eq('audit.app.package.upload')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          package_guid = event.metadata.fetch('package_guid')
          expect(package_guid).to eq(package.guid)
        end
      end

      describe 'record_app_package_delete' do
        it 'creates a new package delete event' do
          event = PackageEventRepository.record_app_package_delete(package, user_guid, email)
          event.reload

          expect(event.type).to eq('audit.app.package.delete')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          package_guid = event.metadata.fetch('package_guid')
          expect(package_guid).to eq(package.guid)
        end
      end

      describe 'record_app_package_download' do
        it 'creates a new package download event' do
          event = PackageEventRepository.record_app_package_download(package, user_guid, email)
          event.reload

          expect(event.type).to eq('audit.app.package.download')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          package_guid = event.metadata.fetch('package_guid')
          expect(package_guid).to eq(package.guid)
        end
      end
    end
  end
end
