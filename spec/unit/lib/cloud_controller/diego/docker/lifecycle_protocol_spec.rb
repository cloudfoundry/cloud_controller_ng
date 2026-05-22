require 'spec_helper'
require 'cloud_controller/diego/docker/lifecycle_protocol'
require_relative '../lifecycle_protocol_shared'

module VCAP
  module CloudController
    module Diego
      module Docker
        RSpec.describe LifecycleProtocol do
          subject(:lifecycle_protocol) { LifecycleProtocol.new }

          it_behaves_like 'a lifecycle protocol' do
            let(:app) { create(:app_model) }
            let(:package) { create(:package_model, :docker, app:) }
            let(:droplet) { create(:droplet_model, package:, app:) }
            let(:process) { create(:process_model, app:) }

            before do
              app.update(droplet_guid: droplet.guid)
            end

            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.staging_guid = droplet.guid
                details.package = package
                details.lifecycle = instance_double(VCAP::CloudController::DockerLifecycle)
              end
            end
          end

          describe '#lifecycle_data' do
            let(:app) { create(:app_model) }
            let(:package) do
              create(:package_model, :docker,
                     app: app,
                     docker_image: 'registry/image-name:latest',
                     docker_username: 'dockerusername',
                     docker_password: 'dockerpassword')
            end
            let(:droplet) { create(:droplet_model, package_guid: package.guid) }
            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.staging_guid = droplet.guid
                details.package = package
                details.lifecycle = instance_double(VCAP::CloudController::DockerLifecycle)
              end
            end

            it 'sets the docker image' do
              message = lifecycle_protocol.lifecycle_data(staging_details)
              expect(message[:docker_image]).to eq('registry/image-name:latest')
              expect(message[:docker_user]).to eq('dockerusername')
              expect(message[:docker_password]).to eq('dockerpassword')
            end
          end

          describe '#desired_lrp_builder' do
            let(:config) { Config.new({}) }
            let(:app) { create(:app_model, droplet:) }
            let(:droplet) do
              create(:droplet_model, :docker, {
                       state: DropletModel::STAGED_STATE,
                       docker_receipt_image: 'the-image',
                       execution_metadata: 'foobar'
                     })
            end
            let(:process) { create(:process_model, app: app, diego: true, command: 'go go go', user: 'ContainerUser', metadata: {}) }
            let(:builder_opts) do
              {
                ports: [8080],
                docker_image: 'the-image',
                execution_metadata: 'foobar',
                start_command: 'go go go',
                action_user: 'ContainerUser',
                additional_container_env_vars: []
              }
            end

            it 'creates a diego DesiredLrpBuilder' do
              expect(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder).to receive(:new).with(
                config,
                builder_opts
              )
              lifecycle_protocol.desired_lrp_builder(config, process)
            end

            context 'when revisions are enabled' do
              before do
                app.update(revisions_enabled: true)
              end

              context 'and theres a revision on the process' do
                let(:new_droplet) { create(:droplet_model, :docker, app: app, docker_receipt_image: 'trololol', set_as_current_droplet: false) }
                let(:revision) { create(:revision_model, app: app, droplet_guid: new_droplet.guid) }

                before do
                  process.update(revision:)
                end

                it 'uses the droplet from the revision' do
                  builder_opts[:docker_image] = new_droplet.docker_receipt_image
                  expect(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder).to receive(:new).with(
                    config,
                    builder_opts
                  )
                  lifecycle_protocol.desired_lrp_builder(config, process)
                end
              end

              context 'but theres not a revision on the process' do
                it 'uses the droplet from the process' do
                  builder_opts[:docker_image] = droplet.docker_receipt_image
                  expect(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder).to receive(:new).with(
                    config,
                    builder_opts
                  )
                  lifecycle_protocol.desired_lrp_builder(config, process)
                end
              end
            end

            context 'when root user is allowed' do
              let(:app) { create(:app_model, :docker, { droplet: }) }

              before do
                TestConfig.override(allow_docker_root_user: true, additional_allowed_process_users: %w[root 0])
              end

              context 'and the process sets the root user' do
                let(:process) { create(:process_model, :docker, { app: app, user: 'root' }) }

                it 'creates a diego DesiredLrpBuilder' do
                  expect do
                    lifecycle_protocol.desired_lrp_builder(config, process)
                  end.not_to raise_error
                end
              end

              context 'and the process does not set a user' do
                let(:process) { create(:process_model, :docker, { app: }) }

                context 'and the droplet docker execution metadata sets the root user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"root"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'creates a diego DesiredLRPBuilder' do
                    expect do
                      lifecycle_protocol.desired_lrp_builder(config, process)
                    end.not_to raise_error
                  end
                end

                context 'and the droplet docker execution metadata sets the 0 user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"0"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'creates a diego TaskActionBuilder' do
                    expect do
                      lifecycle_protocol.desired_lrp_builder(config, process)
                    end.not_to raise_error
                  end
                end

                context 'and the droplet docker execution metadata does not set a user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"]}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'creates a diego TaskActionBuilder' do
                    expect do
                      lifecycle_protocol.desired_lrp_builder(config, process)
                    end.not_to raise_error
                  end
                end
              end
            end

            context 'when root user IS NOT allowed' do
              let(:app) { create(:app_model, :docker, { droplet: }) }

              before do
                TestConfig.override(allow_docker_root_user: false, additional_allowed_process_users: %w[root 0])
              end

              context 'and the process does not set a user' do
                let(:process) { create(:process_model, :docker, { app: }) }

                context 'and the droplet docker execution metadata sets the root user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"root"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'raises an error' do
                    expect do
                      lifecycle_protocol.desired_lrp_builder(config, process)
                    end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run process as root user, which is not permitted/)
                  end
                end

                context 'and the droplet docker execution metadata sets the 0 user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"0"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'raises an error' do
                    expect do
                      lifecycle_protocol.desired_lrp_builder(config, process)
                    end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run process as root user, which is not permitted/)
                  end
                end

                context 'and the droplet docker execution metadata does not set a user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"]}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'raises an error' do
                    expect do
                      lifecycle_protocol.desired_lrp_builder(config, process)
                    end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run process as root user, which is not permitted/)
                  end
                end
              end

              context 'and the process sets the root user' do
                let(:process) { create(:process_model, :docker, { app: app, user: 'root' }) }

                it 'raises an error' do
                  expect do
                    lifecycle_protocol.desired_lrp_builder(config, process)
                  end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run process as root user, which is not permitted/)
                end
              end

              context 'and the process sets the 0 user' do
                let(:process) { create(:process_model, :docker, { app: app, user: 0 }) }

                it 'raises an error' do
                  expect do
                    lifecycle_protocol.desired_lrp_builder(config, process)
                  end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run process as root user, which is not permitted/)
                end
              end
            end
          end

          describe '#task_action_builder' do
            let(:config) { Config.new({}) }
            let(:droplet) { create(:droplet_model, :docker, docker_receipt_image: 'repository/the-image') }
            let(:task) { create(:task_model, droplet:) }
            let(:lifecycle_data) do
              {
                droplet_path: 'repository/the-image'
              }
            end

            it 'creates a diego TaskActionBuilder' do
              expect(VCAP::CloudController::Diego::Docker::TaskActionBuilder).to receive(:new).with(
                config,
                task,
                lifecycle_data
              )
              lifecycle_protocol.task_action_builder(config, task)
            end

            context 'when root user is allowed' do
              before do
                TestConfig.override(allow_docker_root_user: true, additional_allowed_process_users: %w[root 0])
              end

              context 'and the task does not set a user' do
                let(:app) { create(:app_model, :docker, { droplet: }) }
                let(:task) { create(:task_model, :docker, { droplet:, app: }) }

                context 'and the droplet docker execution metadata sets the root user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"root"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'creates a diego TaskActionBuilder' do
                    expect do
                      lifecycle_protocol.task_action_builder(config, task)
                    end.not_to raise_error
                  end
                end

                context 'and the droplet docker execution metadata sets the 0 user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"0"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'creates a diego TaskActionBuilder' do
                    expect do
                      lifecycle_protocol.task_action_builder(config, task)
                    end.not_to raise_error
                  end
                end

                context 'and the droplet docker execution metadata does not set a user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"]}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'creates a diego TaskActionBuilder' do
                    expect do
                      lifecycle_protocol.task_action_builder(config, task)
                    end.not_to raise_error
                  end
                end
              end
            end

            context 'when root user IS NOT allowed' do
              before do
                TestConfig.override(allow_docker_root_user: false, additional_allowed_process_users: %w[root 0])
              end

              context 'and the task does not set a user' do
                let(:app) { create(:app_model, :docker, { droplet: }) }
                let(:task) { create(:task_model, :docker, { droplet:, app: }) }

                context 'and the droplet docker execution metadata sets the root user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"root"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'raises an error' do
                    expect do
                      lifecycle_protocol.task_action_builder(config, task)
                    end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run task as root user, which is not permitted/)
                  end
                end

                context 'and the droplet docker execution metadata sets the 0 user' do
                  let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"0"}' }
                  let(:droplet) do
                    create(:droplet_model, :docker, {
                             state: DropletModel::STAGED_STATE,
                             docker_receipt_image: 'the-image',
                             execution_metadata: droplet_execution_metadata
                           })
                  end

                  it 'raises an error' do
                    expect do
                      lifecycle_protocol.task_action_builder(config, task)
                    end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run task as root user, which is not permitted/)
                  end
                end
              end

              context 'and the task sets the root user' do
                let(:app) { create(:app_model, :docker, { droplet: }) }
                let(:task) { create(:task_model, :docker, { droplet: droplet, app: app, user: 'root' }) }

                it 'raises an error' do
                  expect do
                    lifecycle_protocol.task_action_builder(config, task)
                  end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run task as root user, which is not permitted/)
                end
              end

              context 'and the task sets the 0 user' do
                let(:app) { create(:app_model, :docker, { droplet: }) }
                let(:task) { create(:task_model, :docker, { droplet: droplet, app: app, user: '0' }) }

                it 'raises an error' do
                  expect do
                    lifecycle_protocol.task_action_builder(config, task)
                  end.to raise_error(::CloudController::Errors::ApiError, /Attempting to run task as root user, which is not permitted/)
                end
              end
            end
          end
        end
      end
    end
  end
end
