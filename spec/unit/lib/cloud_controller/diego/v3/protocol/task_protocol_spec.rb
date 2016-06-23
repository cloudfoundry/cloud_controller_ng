require 'spec_helper'
require 'cloud_controller/diego/v3/protocol/task_protocol'
require_relative '../../lifecycle_protocol_shared'

module VCAP::CloudController
  module Diego
    module V3
      module Protocol
        RSpec.describe TaskProtocol do
          let(:default_health_check_timeout) { 99 }
          let(:egress_rules) { double(:egress_rules) }

          subject(:protocol) do
            TaskProtocol.new(egress_rules)
          end

          before do
            allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
            allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
          end

          describe '#task_request' do
            let(:user) { 'user' }
            let(:password) { 'password' }
            let(:internal_service_hostname) { 'internal_service_hostname' }
            let(:external_port) { 8080 }
            let(:config) do
              {
                internal_api: {
                  auth_user:     user,
                  auth_password: password,
                },
                internal_service_hostname: internal_service_hostname,
                external_port:             external_port,
                default_app_disk_in_mb:    1024,
              }
            end

            before do
              allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:v3_droplet_download_url).and_return('www.droplet.url')
              allow_any_instance_of(VCAP::CloudController::Diego::V3::Protocol::TaskProtocol).
                to receive(:envs_for_diego).
                and_return(expected_envs)
            end

            let(:expected_envs) { [{ 'name' => 'VCAP_APPLICATION', 'value' => 'utako' }, { 'name' => 'VCAP_SERVICES', 'value' => 'simon' }] }
            let(:task) { TaskModel.make(app_guid: app.guid, droplet_guid: droplet.guid, command: 'be rake my panda', memory_in_mb: 2048) }

            context 'the task has a buildpack droplet' do
              let(:app) { AppModel.make }
              let(:droplet) { DropletModel.make(:buildpack, app_guid: app.guid, droplet_hash: 'some_hash') }

              before do
                app.buildpack_lifecycle_data = BuildpackLifecycleDataModel.make
                app.save
              end

              it 'contains the correct payload for creating a task' do
                result = protocol.task_request(task, config)

                expect(JSON.parse(result)).to match({
                  'task_guid' => task.guid,
                  'rootfs' => app.lifecycle_data.stack,
                  'log_guid' => app.guid,
                  'environment' => expected_envs,
                  'memory_mb' => task.memory_in_mb,
                  'disk_mb' => 1024,
                  'egress_rules' => ['running_egress_rule'],
                  'droplet_uri' => 'www.droplet.url',
                  'droplet_hash' => 'some_hash',
                  'lifecycle' => Lifecycles::BUILDPACK,
                  'command' => 'be rake my panda',
                  'completion_callback' => "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/tasks/#{task.guid}/completed",
                  'log_source' => 'APP/TASK/' + task.name,
                  'volume_mounts' => an_instance_of(Array)
                })
              end
            end

            context 'the task has a docker file droplet' do
              let(:app) { AppModel.make }
              let(:droplet) { DropletModel.make(:docker, app_guid: app.guid, environment_variables: { 'foo' => 'bar' }, docker_receipt_image: 'cloudfoundry/capi-docker') }

              it 'contains the correct payload for creating a task' do
                result = protocol.task_request(task, config)

                expect(JSON.parse(result)).to match({
                  'task_guid' => task.guid,
                  'log_guid' => app.guid,
                  'environment' => expected_envs,
                  'memory_mb' => task.memory_in_mb,
                  'disk_mb' => 1024,
                  'egress_rules' => ['running_egress_rule'],
                  'docker_path' => 'cloudfoundry/capi-docker',
                  'lifecycle' => Lifecycles::DOCKER,
                  'command' => 'be rake my panda',
                  'completion_callback' => "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/tasks/#{task.guid}/completed",
                  'log_source' => 'APP/TASK/' + task.name,
                  'volume_mounts' => an_instance_of(Array)
                })
              end
            end
          end
        end
      end
    end
  end
end
