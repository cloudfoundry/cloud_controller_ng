require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe RecipeBuilder do
      subject(:recipe_builder) { RecipeBuilder.new }

      describe '#build_staging_task' do
        let(:app) { AppModel.make(guid: 'banana-guid') }
        let(:staging_details) do
          Diego::StagingDetails.new.tap do |details|
            details.droplet               = droplet
            details.package               = package
            details.environment_variables = { 'nightshade_fruit' => 'potato' }
            details.staging_memory_in_mb  = 42
            details.staging_disk_in_mb    = 51
            details.start_after_staging   = true
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
            staging:                   {
              timeout_in_seconds: 90,
            },
            diego:                     {
              use_privileged_containers_for_staging: false,
              stager_url:                            'http://stager.example.com',
            },
          }
        end
        let(:internal_service_hostname) { 'internal.awesome.sauce' }
        let(:external_port) { '7777' }
        let(:user) { 'user' }
        let(:password) { 'password' }
        let(:rule_dns_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     'udp',
            destinations: ['0.0.0.0/0'],
            ports:        [53]
          )
        end
        let(:rule_http_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     'tcp',
            destinations: ['0.0.0.0/0'],
            ports:        [80],
            log:          true
          )
        end

        before do
          SecurityGroup.make(rules: [{ 'protocol' => 'udp', 'ports' => '53', 'destination' => '0.0.0.0/0' }], staging_default: true)
          SecurityGroup.make(rules: [{ 'protocol' => 'tcp', 'ports' => '80', 'destination' => '0.0.0.0/0', 'log' => true }], staging_default: true)
        end

        context 'with a buildpack backend' do
          let(:droplet) { DropletModel.make(:buildpack, package: package, app: app) }
          let(:package) { PackageModel.make(app: app) }

          let(:buildpack_staging_action) { ::Diego::Bbs::Models::RunAction.new }
          let(:lifecycle_action_builder) do
            instance_double(
              Buildpack::StagingActionBuilder,
              stack:                      'potato-stack',
              action:                     buildpack_staging_action,
              task_environment_variables: 'the-buildpack-env-vars',
              cached_dependencies:        'buildpack-cached-deps',
            )
          end

          let(:lifecycle_type) { 'buildpack' }
          let(:lifecycle_protocol) do
            instance_double(VCAP::CloudController::Diego::Buildpack::LifecycleProtocol,
              action_builder: lifecycle_action_builder
            )
          end

          before do
            allow(LifecycleProtocol).to receive(:protocol_for_type).with(lifecycle_type).and_return(lifecycle_protocol)
          end

          it 'constructs a TaskDefinition with staging instructions' do
            result = recipe_builder.build_staging_task(config, staging_details)

            expect(result.root_fs).to eq('preloaded:potato-stack')
            expect(result.log_guid).to eq('banana-guid')
            expect(result.metrics_guid).to be_nil
            expect(result.log_source).to eq('STG')
            expect(result.result_file).to eq('/tmp/result.json')
            expect(result.privileged).to be(false)

            expect(result.memory_mb).to eq(42)
            expect(result.disk_mb).to eq(51)
            expect(result.cpu_weight).to eq(50)
            expect(result.legacy_download_user).to eq('vcap')

            annotation = JSON.parse(result.annotation)
            expect(annotation['lifecycle']).to eq(lifecycle_type)
            expect(annotation['completion_callback']).to eq("http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}" \
                                   "/internal/v3/staging/#{droplet.guid}/droplet_completed?start=#{staging_details.start_after_staging}")

            timeout_action = result.action.timeout_action
            expect(timeout_action).not_to be_nil
            expect(timeout_action.timeout_ms).to eq(90 * 1000)

            expect(timeout_action.action.run_action).to eq(buildpack_staging_action)

            expect(result.egress_rules).to eq([
              rule_dns_everywhere,
              rule_http_everywhere
            ])

            expect(result.cached_dependencies).to eq('buildpack-cached-deps')
          end

          it 'sets the completion callback to the stager callback url' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.completion_callback_url).to eq("http://stager.example.com/v1/staging/#{droplet.guid}/completed")
          end

          it 'gives the task a TrustedSystemCertificatesPath' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.trusted_system_certificates_path).to eq('/etc/cf-system-certificates')
          end

          it 'sets the env vars' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.environment_variables).to eq('the-buildpack-env-vars')
          end
        end

        context 'with a docker backend' do
          let(:droplet) { DropletModel.make(:docker, package: package, app: app) }
          let(:package) { PackageModel.make(:docker, app: app) }

          let(:docker_staging_action) { ::Diego::Bbs::Models::RunAction.new }
          let(:lifecycle_type) { 'docker' }
          let(:lifecycle_action_builder) do
            instance_double(
              Docker::StagingActionBuilder,
              stack:                      'docker-stack',
              action:                     docker_staging_action,
              task_environment_variables: 'the-docker-env-vars',
              cached_dependencies:        'docker-cached-deps',
            )
          end

          before do
            allow(Docker::StagingActionBuilder).to receive(:new).and_return(lifecycle_action_builder)
          end

          it 'sets the log guid' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.log_guid).to eq('banana-guid')
          end

          it 'sets the log source' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.log_source).to eq('STG')
          end

          it 'sets the result file' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.result_file).to eq('/tmp/result.json')
          end

          it 'sets privileged container to the config value' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.privileged).to be(false)
          end

          it 'sets the legacy download user' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.legacy_download_user).to eq('vcap')
          end

          it 'sets the annotation' do
            result = recipe_builder.build_staging_task(config, staging_details)

            annotation = JSON.parse(result.annotation)
            expect(annotation['lifecycle']).to eq(lifecycle_type)
            expect(annotation['completion_callback']).to eq("http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}" \
                                   "/internal/v3/staging/#{droplet.guid}/droplet_completed?start=#{staging_details.start_after_staging}")
          end

          it 'sets the cached dependencies' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.cached_dependencies).to eq('docker-cached-deps')
          end

          it 'sets the memory' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.memory_mb).to eq(42)
          end

          it 'sets the disk' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.disk_mb).to eq(51)
          end

          it 'sets the egress rules' do
            result = recipe_builder.build_staging_task(config, staging_details)

            expect(result.egress_rules).to eq([
              rule_dns_everywhere,
              rule_http_everywhere
            ])
          end

          it 'sets the rootfs' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.root_fs).to eq('preloaded:docker-stack')
          end

          it 'sets the completion callback' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.completion_callback_url).to eq("http://stager.example.com/v1/staging/#{droplet.guid}/completed")
          end

          it 'sets the trusted cert path' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.trusted_system_certificates_path).to eq('/etc/cf-system-certificates')
          end

          it 'sets the timeout and sets the run action' do
            result = recipe_builder.build_staging_task(config, staging_details)

            timeout_action = result.action.timeout_action
            expect(timeout_action).not_to be_nil
            expect(timeout_action.timeout_ms).to eq(90 * 1000)

            expect(timeout_action.action.run_action).to eq(docker_staging_action)
          end
        end
      end
    end
  end
end
