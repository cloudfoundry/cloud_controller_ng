require 'spec_helper'
require 'repositories/buildpack_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe BuildpackEventRepository do
      let(:request_attrs) { { 'name' => 'new-buildpack' } }
      let(:user) { User.make }
      let(:buildpack) { Buildpack.make }
      let(:user_email) { 'email address' }
      let(:user_name) { 'user name' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user.guid, user_name: user_name) }

      subject(:buildpack_event_repository) { BuildpackEventRepository.new }

      describe '#record_buildpack_create' do
        it 'records event correctly' do
          event = buildpack_event_repository.record_buildpack_create(buildpack, user_audit_info, request_attrs)
          event.reload
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.type).to eq('audit.buildpack.create')
          expect(event.actee).to eq(buildpack.guid)
          expect(event.actee_type).to eq('buildpack')
          expect(event.actee_name).to eq(buildpack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_buildpack_update' do
        it 'records event correctly' do
          event = buildpack_event_repository.record_buildpack_update(buildpack, user_audit_info, request_attrs)
          event.reload
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.type).to eq('audit.buildpack.update')
          expect(event.actee).to eq(buildpack.guid)
          expect(event.actee_type).to eq('buildpack')
          expect(event.actee_name).to eq(buildpack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_buildpack_delete' do
        it 'records event correctly' do
          event = buildpack_event_repository.record_buildpack_delete(buildpack, user_audit_info)
          event.reload
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.type).to eq('audit.buildpack.delete')
          expect(event.actee).to eq(buildpack.guid)
          expect(event.actee_type).to eq('buildpack')
          expect(event.actee_name).to eq(buildpack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({})
        end
      end

      describe '#record_buildpack_upload' do
        it 'records event correctly' do
          event = buildpack_event_repository.record_buildpack_upload(buildpack, user_audit_info, request_attrs)
          event.reload
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.type).to eq('audit.buildpack.upload')
          expect(event.actee).to eq(buildpack.guid)
          expect(event.actee_type).to eq('buildpack')
          expect(event.actee_name).to eq(buildpack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end
    end
  end
end
