require 'spec_helper'
require 'cloud_controller/diego/task_protocol'
require_relative 'lifecycle_protocol_shared'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskProtocol do
      subject(:protocol) { TaskProtocol.new(egress_rules) }

      let(:default_health_check_timeout) { 99 }
      let(:egress_rules) { double(:egress_rules) }

      before do
        allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
      end

      describe '#task_request' do
        let(:user) { 'user' }
        let(:password) { 'password' }
        let(:internal_service_hostname) { 'internal_service_hostname' }
        let(:external_port) { 8081 }
        let(:tls_port) { 8080 }
        let(:config) do
          Config.new({
            internal_api:              {
              auth_user:     user,
              auth_password: password,
            },
            internal_service_hostname: internal_service_hostname,
            external_port:             external_port,
            tls_port:             tls_port,
            default_app_disk_in_mb:    1024,
          })
        end

        before do
          allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:droplet_download_url).and_return('www.droplet.url')
          allow_any_instance_of(VCAP::CloudController::Diego::TaskProtocol).
            to receive(:envs_for_diego).
            and_return(expected_envs)
        end

        let(:expected_envs) { [{ 'name' => 'VCAP_APPLICATION', 'value' => 'utako' }, { 'name' => 'VCAP_SERVICES', 'value' => 'simon' }] }
        let(:task) { TaskModel.make(app_guid: app.guid, droplet_guid: droplet.guid, command: 'be rake my panda', memory_in_mb: 2048, disk_in_mb: 2048) }

        context 'the task has a buildpack droplet' do
          let(:app) { AppModel.make }
          let(:droplet) { DropletModel.make(:buildpack, app_guid: app.guid, droplet_hash: 'some_hash', sha256_checksum: 'droplet-sha256-checksum') }

          before do
            allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])

            app.buildpack_lifecycle_data = BuildpackLifecycleDataModel.make
            app.save
          end

          it 'contains the correct payload for creating a task' do
            result = protocol.task_request(task, config)

            expect(JSON.parse(result)).to match({
              'task_guid'           => task.guid,
              'rootfs'              => app.lifecycle_data.stack,
              'log_guid'            => app.guid,
              'environment'         => expected_envs,
              'memory_mb'           => task.memory_in_mb,
              'disk_mb'             => 2048,
              'egress_rules'        => ['running_egress_rule'],
              'droplet_uri'         => 'www.droplet.url',
              'droplet_hash'        => 'some_hash',
              'lifecycle'           => Lifecycles::BUILDPACK,
              'command'             => 'be rake my panda',
              'completion_callback' => "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/tasks/#{task.guid}/completed",
              'log_source'          => 'APP/TASK/' + task.name,
              'volume_mounts'       => an_instance_of(Array)
            })
          end
        end

        describe 'isolation segments' do
          let(:org) { Organization.make }
          let(:space) { Space.make(organization: org) }
          let(:app) { AppModel.make(space: space) }
          let(:droplet) { DropletModel.make(:buildpack, app_guid: app.guid, droplet_hash: 'some_hash', sha256_checksum: 'droplet-sha256-checksum') }
          let(:task) { TaskModel.make(app_guid: app.guid, droplet_guid: droplet.guid, command: 'be rake my panda', memory_in_mb: 2048, disk_in_mb: 2048) }

          let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
          let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:isolation_segment_model_2) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:shared_isolation_segment) {
            VCAP::CloudController::IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
          }
          let(:result) { JSON.parse(protocol.task_request(task, config)) }

          before do
            allow(egress_rules).to receive(:running).and_return(['running_egress_rule'])
          end

          context 'when the org has a default' do
            before do
              assigner.assign(shared_isolation_segment, [org])
              assigner.assign(isolation_segment_model, [org])
            end

            context 'and the default is the shared isolation segments' do
              it 'does not set an isolation segment' do
                expect(result['isolation_segment']).to be_nil
              end
            end

            context 'and the default is not the shared isolation segment' do
              before do
                org.update(default_isolation_segment_model: isolation_segment_model)
              end

              it 'sets the isolation segment' do
                expect(result['isolation_segment']).to eq(isolation_segment_model.name)
              end

              context 'and the space from that org has an isolation segment' do
                context 'and the isolation segment is the shared isolation segment' do
                  before do
                    space.isolation_segment_model = shared_isolation_segment
                    space.save
                  end

                  it 'does not set the isolation segment' do
                    expect(result['isolation_segment']).to be_nil
                  end
                end

                context 'and the isolation segment is not the shared or the default' do
                  before do
                    assigner.assign(isolation_segment_model_2, [org])
                    space.isolation_segment_model = isolation_segment_model_2
                    space.save
                  end

                  it 'sets the IS from the space' do
                    expect(result['isolation_segment']).to eq(isolation_segment_model_2.name)
                  end
                end
              end
            end
          end

          context 'when the org does not have a default' do
            context 'and the space from that org has an isolation segment' do
              context 'and the isolation segment is not the shared isolation segment' do
                before do
                  assigner.assign(isolation_segment_model, [org])
                  space.isolation_segment_model = isolation_segment_model
                  space.save
                end

                it 'sets the isolation segment' do
                  expect(result['isolation_segment']).to eq(isolation_segment_model.name)
                end
              end
            end
          end
        end

        context 'the task has a docker file droplet' do
          let(:app) { AppModel.make(:docker) }
          let(:droplet) do
            DropletModel.make(:docker,
                              app: app,
                              docker_receipt_image: 'cloudfoundry/capi-docker',
                             )
          end

          before do
            allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
          end

          it 'contains the correct payload for creating a task' do
            result = protocol.task_request(task, config)

            expect(JSON.parse(result)).to match({
              'task_guid'           => task.guid,
              'log_guid'            => app.guid,
              'environment'         => expected_envs,
              'memory_mb'           => task.memory_in_mb,
              'disk_mb'             => task.disk_in_mb,
              'egress_rules'        => ['running_egress_rule'],
              'docker_path'         => 'cloudfoundry/capi-docker',
              'lifecycle'           => Lifecycles::DOCKER,
              'command'             => 'be rake my panda',
              'completion_callback' => "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/tasks/#{task.guid}/completed",
              'log_source'          => 'APP/TASK/' + task.name,
              'volume_mounts'       => an_instance_of(Array)
            })
          end

          context 'the droplet contains docker credentials' do
            let(:droplet) do
              DropletModel.make(:docker,
                                app: app,
                                docker_receipt_image: 'cloudfoundry/capi-docker',
                                docker_receipt_username: 'dockerusername',
                                docker_receipt_password: 'dockerpassword',
                               )
            end

            it 'contains the credentials in the task request' do
              result = protocol.task_request(task, config)

              expect(JSON.parse(result)).to include({
                'docker_user'     => 'dockerusername',
                'docker_password' => 'dockerpassword',
              })
            end
          end
        end
      end
    end
  end
end
