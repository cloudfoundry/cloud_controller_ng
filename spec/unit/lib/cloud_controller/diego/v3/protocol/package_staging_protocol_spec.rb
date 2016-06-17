require 'spec_helper'
require_relative '../../lifecycle_protocol_shared'
require 'cloud_controller/diego/v3/protocol/package_staging_protocol'

module VCAP::CloudController
  module Diego
    module V3
      module Protocol
        class FakeLifecycleProtocol
          def lifecycle_data(_, _)
            ['fake', { 'some' => 'data' }]
          end
        end

        RSpec.describe FakeLifecycleProtocol do
          let(:lifecycle_protocol) { FakeLifecycleProtocol.new }

          it_behaves_like 'a v3 lifecycle protocol'
        end

        RSpec.describe PackageStagingProtocol do
          let(:default_health_check_timeout) { 99 }
          let(:egress_rules) { double(:egress_rules) }
          let(:lifecycle_type) { 'dev/null' }

          subject(:protocol) { PackageStagingProtocol.new(lifecycle_type, egress_rules) }

          before do
            allow(Diego::V3::LifecycleProtocol).to receive(:protocol_for_type).
              with(lifecycle_type).and_return(FakeLifecycleProtocol.new)
            allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
            allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
          end

          describe '#stage_package_request' do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: app.guid) }
            let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: app.guid) }
            let(:staging_details) do
              Diego::V3::StagingDetails.new.tap do |details|
                details.droplet               = droplet
                details.environment_variables = { 'nightshade_fruit' => 'potato' }
                details.staging_memory_in_mb  = 42
                details.staging_disk_in_mb    = 51
              end
            end
            let(:config) do
              {
                external_port:             external_port,
                internal_service_hostname: internal_service_hostname,
                internal_api:              {
                  auth_user:     user,
                  auth_password: password
                },
                staging: {
                  minimum_staging_memory_mb:             128,
                  minimum_staging_file_descriptor_limit: 30,
                  timeout_in_seconds:                    90,
                }
              }
            end
            let(:internal_service_hostname) { 'internal.awesome.sauce' }
            let(:external_port) { '7777' }
            let(:user) { 'user' }
            let(:password) { 'password' }

            it 'contains the correct payload for staging a package' do
              result = protocol.stage_package_request(package, config, staging_details)

              expect(result).to eq({
                app_id:              staging_details.droplet.guid,
                log_guid:            app.guid,
                memory_mb:           staging_details.staging_memory_in_mb,
                disk_mb:             staging_details.staging_disk_in_mb,
                file_descriptors:    30,
                environment:         VCAP::CloudController::Diego::NormalEnvHashToDiegoEnvArrayPhilosopher.muse(staging_details.environment_variables),
                egress_rules:        ['staging_egress_rule'],
                timeout:             90,
                lifecycle:           'fake',
                lifecycle_data:      { 'some' => 'data' },
                completion_callback: "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/staging/#{droplet.guid}/droplet_completed"
              })
            end
          end
        end
      end
    end
  end
end
