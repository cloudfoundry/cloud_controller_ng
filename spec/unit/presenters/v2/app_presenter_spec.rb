require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe AppPresenter do
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
      let(:app) do
        VCAP::CloudController::AppFactory.make(
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

      before do
        app.app.lifecycle_data.update(
          buildpack: buildpack
        )
        app.current_droplet.update(
          buildpack_receipt_detect_output:  'detected buildpack',
          buildpack_receipt_buildpack_guid: 'i am a buildpack guid',
        )
        VCAP::CloudController::DropletModel.make(app: app.app, package: app.latest_package, error_description: 'because')
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
          'version'                    => app.version,
          'command'                    => 'start',
          'console'                    => anything,
          'debug'                      => anything,
          'staging_task_id'            => app.latest_droplet.guid,
          'package_state'              => 'PENDING',
          'health_check_type'          => 'port',
          'health_check_timeout'       => nil,
          'staging_failed_reason'      => anything,
          'staging_failed_description' => 'because',
          'diego'                      => true,
          'docker_image'               => anything,
          'package_updated_at'         => anything,
          'detected_start_command'     => anything,
          'enable_ssh'                 => true,
          'docker_credentials_json'    => anything,
          'ports'                      => [8080],
          'relationship_key'           => 'relationship_value'
        }

        actual_entity_hash = app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

        expect(actual_entity_hash).to be_a_response_like(expected_entity_hash)
        expect(relations_presenter).to have_received(:to_hash).with(controller, app, opts, depth, parents, orphans)
      end

      describe 'buildpacks' do
        context 'with a custom buildpack' do
          it 'displays the correct url' do
            actual_entity_hash = app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

            expect(actual_entity_hash['buildpack']).to eq 'https://github.com/custombuildpack'
            expect(relations_presenter).to have_received(:to_hash).with(controller, app, opts, depth, parents, orphans)
          end

          it 'calls out to the UrlSecretObfuscator' do
            allow(CloudController::UrlSecretObfuscator).to receive(:obfuscate)

            app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

            expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
          end
        end

        context 'with an admin buildpack' do
          let(:buildpack) { 'schmuby' }

          before { VCAP::CloudController::Buildpack.make(name: 'schmuby') }

          it 'displays the correct url' do
            actual_entity_hash = app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

            expect(actual_entity_hash['buildpack']).to eq 'schmuby'
            expect(relations_presenter).to have_received(:to_hash).with(controller, app, opts, depth, parents, orphans)
          end
        end
      end

      describe 'ports' do
        before do
          allow_any_instance_of(VCAP::CloudController::Diego::Protocol::OpenProcessPorts).to receive(:to_a).and_return('expected-ports')
        end

        it 'delegates to OpenProcessPorts' do
          actual_entity_hash = app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

          expect(actual_entity_hash['ports']).to eq('expected-ports')
        end
      end

      context 'redacting' do
        context 'when the user is an admin' do
          before { allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true) }

          it 'only redacts the docker credentials' do
            actual_entity_hash = app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

            expect(actual_entity_hash['docker_credentials_json']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(actual_entity_hash['environment_json']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
          end
        end

        context 'when the user is an admin-read-only' do
          before { allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true) }

          it 'only redacts the docker credentials' do
            actual_entity_hash = app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

            expect(actual_entity_hash['docker_credentials_json']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(actual_entity_hash['environment_json']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
          end
        end

        context 'when the user is a space developer' do
          before { allow(app.space).to receive(:has_developer?).and_return(true) }

          it 'redacts the docker credentials and the environment json' do
            actual_entity_hash = app_presenter.entity_hash(controller, app, opts, depth, parents, orphans)

            expect(actual_entity_hash['docker_credentials_json']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(actual_entity_hash['environment_json']).to eq({ 'UNICORNS' => 'RAINBOWS' })
          end
        end
      end
    end
  end
end
