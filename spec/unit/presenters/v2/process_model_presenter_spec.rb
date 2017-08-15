require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ProcessModelPresenter do
    let(:app_presenter) { described_class.new }
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_key' => 'relationship_value' } }

    describe '#entity_hash' do
      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      let(:space) { VCAP::CloudController::Space.make }
      let(:stack) { VCAP::CloudController::Stack.make }
      let(:process) do
        VCAP::CloudController::ProcessModelFactory.make(
          name:             'utako',
          space:            space,
          stack:            stack,
          environment_json: { 'UNICORNS': 'RAINBOWS' },
          memory:           1024,
          disk_quota:       1024,
          state:            'STOPPED',
          command:          'start',
          enable_ssh:       true,
          diego:            diego,
        )
      end
      let(:diego) { true }
      let(:buildpack) { 'https://github.com/custombuildpack' }
      let(:buildpacks) { [buildpack] }

      before do
        VCAP::CloudController::Buildpack.make(name: 'schmuby')
        process.app.lifecycle_data.update(
          buildpacks: buildpacks
        )
        process.current_droplet.update(
          buildpack_receipt_detect_output:  'detected buildpack',
          buildpack_receipt_buildpack_guid: 'i am a buildpack guid',
        )
        VCAP::CloudController::DropletModel.make(app: process.app, package: process.latest_package, error_description: 'because')
      end

      it 'returns the app entity and associated urls' do
        expected_entity_hash = {
          'name'                       => 'utako',
          'production'                 => anything,
          'space_guid'                 => space.guid,
          'stack_guid'                 => stack.guid,
          'buildpack'                  => 'https://github.com/custombuildpack',
          'detected_buildpack'         => 'detected buildpack',
          'detected_buildpack_guid'    => 'i am a buildpack guid',
          'environment_json'           => { 'redacted_message' => '[PRIVATE DATA HIDDEN]' },
          'memory'                     => 1024,
          'instances'                  => 1,
          'disk_quota'                 => 1024,
          'state'                      => 'STOPPED',
          'version'                    => process.version,
          'command'                    => 'start',
          'console'                    => anything,
          'debug'                      => anything,
          'staging_task_id'            => process.latest_build.guid,
          'package_state'              => 'PENDING',
          'health_check_type'          => 'port',
          'health_check_timeout'       => nil,
          'health_check_http_endpoint' => nil,
          'staging_failed_reason'      => anything,
          'staging_failed_description' => 'because',
          'diego'                      => true,
          'docker_image'               => nil,
          'docker_credentials'         => {
            'username' => nil,
            'password' => nil,
          },
          'package_updated_at'         => anything,
          'detected_start_command'     => anything,
          'enable_ssh'                 => true,
          'ports'                      => [8080],
          'relationship_key'           => 'relationship_value'
        }

        actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

        expect(actual_entity_hash).to be_a_response_like(expected_entity_hash)
        expect(relations_presenter).to have_received(:to_hash).with(controller, process, opts, depth, parents, orphans)
      end

      describe 'nil associated objects' do
        context 'when an associated object is not present' do
          before do
            parent_app = process.app
            process.destroy
            parent_app.builds.map(&:destroy)
            parent_app.packages.map(&:destroy)
            parent_app.droplets.map(&:destroy)
            parent_app.buildpack_lifecycle_data.buildpack_lifecycle_buildpacks.map(&:destroy)
            parent_app.destroy
          end

          it 'returns nil' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)
            expect(actual_entity_hash).to be_nil
          end
        end
      end

      describe 'buildpacks' do
        context 'with a custom buildpack' do
          it 'displays the correct url' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['buildpack']).to eq 'https://github.com/custombuildpack'
            expect(relations_presenter).to have_received(:to_hash).with(controller, process, opts, depth, parents, orphans)
          end

          it 'calls out to the UrlSecretObfuscator' do
            allow(CloudController::UrlSecretObfuscator).to receive(:obfuscate)

            app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
          end
        end

        context 'with an admin buildpack' do
          let(:buildpack) { 'schmuby' }

          it 'displays the correct url' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['buildpack']).to eq 'schmuby'
            expect(relations_presenter).to have_received(:to_hash).with(controller, process, opts, depth, parents, orphans)
          end
        end
      end

      describe 'docker' do
        context 'with no credentials' do
          before do
            VCAP::CloudController::PackageModel.make(:docker, app: process.app, docker_image: 'someimage')
            process.reload
          end

          it 'displays the docker_image' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['docker_image']).to eq('someimage')
            expect(actual_entity_hash['docker_credentials']['username']).to eq(nil)
            expect(actual_entity_hash['docker_credentials']['password']).to eq(nil)
            expect(relations_presenter).to have_received(:to_hash).with(controller, process, opts, depth, parents, orphans)
          end
        end

        context 'with credentials' do
          before do
            VCAP::CloudController::PackageModel.make(:docker, app: process.app, docker_image: 'someimage', docker_username: 'user', docker_password: 'secret')
            process.reload
          end

          it 'displays the docker image and username and redacts the password' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['docker_image']).to eq('someimage')
            expect(actual_entity_hash['docker_credentials']['username']).to eq('user')
            expect(actual_entity_hash['docker_credentials']['password']).to eq('***')
            expect(relations_presenter).to have_received(:to_hash).with(controller, process, opts, depth, parents, orphans)
          end
        end
      end

      describe 'ports' do
        before do
          allow_any_instance_of(VCAP::CloudController::Diego::Protocol::OpenProcessPorts).to receive(:to_a).and_return('expected-ports')
        end

        it 'delegates to OpenProcessPorts' do
          actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

          expect(actual_entity_hash['ports']).to eq('expected-ports')
        end
      end

      context 'redacting' do
        context 'when the user is an admin' do
          before { set_current_user_as_admin }

          it 'displays environment_json' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['environment_json']).to eq({ 'UNICORNS' => 'RAINBOWS' })
          end
        end

        context 'when the user is an admin-read-only' do
          before { set_current_user_as_admin_read_only }

          it 'displays environment_json' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['environment_json']).to eq({ 'UNICORNS' => 'RAINBOWS' })
          end
        end

        context 'when the user is a space developer' do
          before { allow(process.space).to receive(:has_developer?).and_return(true) }

          it 'displays the environment json' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['environment_json']).to eq({ 'UNICORNS' => 'RAINBOWS' })
          end
        end

        context 'when the user is any other role' do
          before { allow(process.space).to receive(:has_developer?).and_return(false) }

          it 'redacts the environment json' do
            actual_entity_hash = app_presenter.entity_hash(controller, process, opts, depth, parents, orphans)

            expect(actual_entity_hash['environment_json']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
          end
        end
      end
    end
  end
end
