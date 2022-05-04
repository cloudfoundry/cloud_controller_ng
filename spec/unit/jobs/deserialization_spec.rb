require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe Jobs do
      context 'SpaceApplyManifestActionJob serialization' do
        let(:user) { User.make(guid: 'user-guid') }
        let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@bommel.com', user_guid: user.guid, user_name: 'user-name') }
        let(:apply_manifest_action) { AppApplyManifest.new(user_audit_info) }
        let(:org) { Organization.make(guid: 'org-guid') }
        let(:space) { Space.make(guid: 'space-guid', name: 'space-name', organization: org,) }
        let(:app) { AppModel.make(guid: 'app-guid', name: 'app-name', space: space) }
        let(:app_manifest_message) {
          AppManifestMessage.create_from_yml({ name: app.name, instances: 4, routes: [{ route: 'app.bommel' }], buildpack: 'ruby', stack: 'cflinuxfs3' })
        }
        let(:app_guid_message_hash) { { app.guid => app_manifest_message } }

        before do
          app_manifest_message.valid?
        end

        subject(:job) { SpaceApplyManifestActionJob.new(space, app_guid_message_hash, apply_manifest_action, user_audit_info) }

        let(:serialized_job) do
          <<~EOS
            --- !ruby/object:VCAP::CloudController::Jobs::LoggingContextJob
            handler: !ruby/object:VCAP::CloudController::Jobs::TimeoutJob
              handler: !ruby/object:VCAP::CloudController::Jobs::SpaceApplyManifestActionJob
                space: !ruby/object:VCAP::CloudController::Space
                  values:
                    :id: #{space.id}
                    :guid: space-guid
                    :created_at: #{space.created_at.strftime('%F %H:%M:%S.%9N Z')}
                    :updated_at: #{space.updated_at.strftime('%F %H:%M:%S.%9N Z')}
                    :name: space-name
                    :organization_id: #{org.id}
                    :space_quota_definition_id:#{' '}
                    :allow_ssh: true
                    :isolation_segment_guid:#{' '}
                app_guid_message_hash:
                  app-guid: &1 !ruby/object:VCAP::CloudController::AppManifestMessage
                    requested_keys:
                    - :name
                    - :instances
                    - :routes
                    - :buildpack
                    - :stack
                    extra_keys: []
                    buildpack: ruby
                    instances: 4
                    name: app-name
                    routes:
                    - :route: app.bommel
                    stack: cflinuxfs3
                    original_yaml:
                      :name: app-name
                      :instances: 4
                      :routes:
                      - :route: app.bommel
                      :buildpack: ruby
                      :stack: cflinuxfs3
                    validation_context:#{' '}
                    errors: !ruby/object:ActiveModel::Errors
                      base: *1
                      errors: []
                    manifest_process_scale_messages:
                    - &2 !ruby/object:VCAP::CloudController::ManifestProcessScaleMessage
                      requested_keys:
                      - :instances
                      - :type
                      extra_keys: []
                      instances: 4
                      type: web
                      validation_context:#{' '}
                      errors: !ruby/object:ActiveModel::Errors
                        base: *2
                        errors: []
                    manifest_process_update_messages: []
                    app_update_message: &3 !ruby/object:VCAP::CloudController::AppUpdateMessage
                      requested_keys:
                      - :lifecycle
                      extra_keys: []
                      lifecycle:
                        :data:
                          :buildpacks:
                          - ruby
                          :stack: cflinuxfs3
                      validation_context:#{' '}
                      errors: !ruby/object:ActiveModel::Errors
                        base: *3
                        errors: []
                    manifest_buildpack_message: &4 !ruby/object:VCAP::CloudController::ManifestBuildpackMessage
                      requested_keys:
                      - :buildpack
                      extra_keys: []
                      buildpack: ruby
                      validation_context:#{' '}
                      errors: !ruby/object:ActiveModel::Errors
                        base: *4
                        errors: []
                    manifest_routes_update_message: &5 !ruby/object:VCAP::CloudController::ManifestRoutesUpdateMessage
                      requested_keys:
                      - :routes
                      extra_keys: []
                      routes:
                      - :route: app.bommel
                      validation_context:#{' '}
                      errors: !ruby/object:ActiveModel::Errors
                        base: *5
                        errors: []
                      manifest_route_mappings:
                      - :route: !ruby/object:VCAP::CloudController::ManifestRoute
                          attrs:
                            :scheme: unspecified
                            :user:#{' '}
                            :password:#{' '}
                            :host: app.bommel
                            :port:#{' '}
                            :path: ''
                            :query:#{' '}
                            :fragment:#{' '}
                            :full_route: app.bommel
                        :protocol:#{' '}
                apply_manifest_action: !ruby/object:VCAP::CloudController::AppApplyManifest
                  user_audit_info: &6 !ruby/object:VCAP::CloudController::UserAuditInfo
                    user_email: user@bommel.com
                    user_name: user-name
                    user_guid: user-guid
                user_audit_info: *6
              timeout: 14400
            request_id:#{' '}
          EOS
        end

        it 'should equal dumped job yaml' do
          VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue
          jobs_in_db = Sequel::Model.db.fetch('SELECT handler FROM delayed_jobs').all
          expect(jobs_in_db.size).to eq(1)

          # We are not interested in minor differences like ordering of nodes. Therefore comparing it as hash.
          permitted_classes = [ActiveModel::Errors, Time, Symbol, UserAuditInfo, AppApplyManifest, ManifestRoute, ManifestRoutesUpdateMessage, ManifestBuildpackMessage,
                               AppUpdateMessage, ManifestProcessScaleMessage, AppManifestMessage, Space, SpaceApplyManifestActionJob, TimeoutJob, LoggingContextJob]
          db_job = YAML.safe_load(jobs_in_db[0][:handler], permitted_classes: permitted_classes, aliases: true).as_json
          dumped_job = YAML.safe_load(serialized_job, permitted_classes: permitted_classes, aliases: true).as_json
          expect(db_job).to eq(dumped_job)
        end

        it 'can be deserialized' do
          object = YAML.load_dj(serialized_job)
          expect(object).not_to be_nil
        end
      end
    end
  end
end
