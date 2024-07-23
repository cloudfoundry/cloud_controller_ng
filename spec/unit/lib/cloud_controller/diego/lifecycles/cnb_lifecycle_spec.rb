require 'spec_helper'
require_relative 'lifecycle_shared'

module VCAP::CloudController
  RSpec.describe CNBLifecycle do
    let(:app) { AppModel.make(:cnb, name: 'some-app') }
    let!(:package) { PackageModel.make(type: PackageModel::BITS_TYPE, app: app) }
    let(:staging_message) { BuildCreateMessage.new(lifecycle: { data: request_data, type: 'cnb' }) }
    let(:request_data) { {} }

    subject(:cnb_lifecycle) { CNBLifecycle.new(package, staging_message) }

    it_behaves_like 'a lifecycle'

    describe '#create_lifecycle_data_model' do
      context 'when the user specifies buildpacks' do
        let(:request_data) do
          {
            buildpacks: %w[docker://nodejs cool-buildpack]
          }
        end

        before do
          Buildpack.make(name: 'cool-buildpack', lifecycle: 'cnb')
          Buildpack.make(name: 'rad-buildpack')
        end

        it 'uses the buildpacks from the user' do
          build = BuildModel.make(:cnb)

          expect do
            cnb_lifecycle.create_lifecycle_data_model(build)
          end.to change(VCAP::CloudController::CNBLifecycleDataModel, :count).by(1)

          data_model = VCAP::CloudController::CNBLifecycleDataModel.last

          expect(data_model.buildpacks).to eq(%w[docker://nodejs cool-buildpack])
          expect(data_model.build).to eq(build)
        end
      end

      context 'when the user does not specify buildpacks' do
        let(:app) { AppModel.make(:cnb, name: 'some-app') }
        let(:request_data) { {} }

        context 'when the app has buildpacks' do
          before do
            app.lifecycle_data.update(buildpacks: %w[docker://cool-buildpack docker://rad-buildpack])
          end

          it 'uses the buildpacks on the app' do
            build = BuildModel.make(:cnb)

            expect do
              cnb_lifecycle.create_lifecycle_data_model(build)
            end.to change(VCAP::CloudController::CNBLifecycleDataModel, :count).by(1)

            data_model = VCAP::CloudController::CNBLifecycleDataModel.last

            expect(data_model.buildpacks).to eq(%w[docker://cool-buildpack docker://rad-buildpack])
            expect(data_model.build).to eq(build)
          end
        end

        context 'when the app does not have buildpacks' do
          it 'does not assign any buildpacks' do
            build = BuildModel.make(:cnb)

            expect do
              cnb_lifecycle.create_lifecycle_data_model(build)
            end.to change(VCAP::CloudController::CNBLifecycleDataModel, :count).by(1)

            data_model = VCAP::CloudController::CNBLifecycleDataModel.last

            expect(data_model.buildpacks).to be_empty
            expect(data_model.build).to eq(build)
          end
        end
      end

      context 'when the user specifies credentials' do
        let(:request_data) do
          { credentials: '{"auth": {}}' }
        end

        it 'uses those credentials' do
          data_model = cnb_lifecycle.create_lifecycle_data_model(BuildModel.make(:cnb))
          expect(data_model.credentials).to eq('{"auth": {}}')
        end
      end

      context 'when the user does not specify credentials' do
        let(:app) { AppModel.make(:cnb, name: 'some-app', space: Space.make) }
        let(:request_data) { {} }

        before do
          app.lifecycle_data.update(credentials: '{"auth": {}}')
        end

        it 'uses credentials from package' do
          data_model = cnb_lifecycle.create_lifecycle_data_model(BuildModel.make(:cnb))
          expect(data_model.credentials).to eq('{"auth": {}}')
        end
      end

      context 'when the user specifies a stack' do
        let(:request_data) do
          { stack: 'cool-stack' }
        end

        it 'uses that stack' do
          data_model = cnb_lifecycle.create_lifecycle_data_model(BuildModel.make(:cnb))
          expect(data_model.stack).to eq('cool-stack')
        end
      end

      context 'when the user does not specify a stack' do
        let(:request_data) { {} }

        context 'when the app has a stack' do
          before do
            app.cnb_lifecycle_data = CNBLifecycleDataModel.make(stack: 'best-stack')
          end

          it 'uses the stack from the app' do
            data_model = cnb_lifecycle.create_lifecycle_data_model(BuildModel.make(:cnb, app:))
            expect(data_model.stack).to eq('best-stack')
          end
        end

        context 'when the app does not have a stack' do
          it 'uses the default stack' do
            data_model = cnb_lifecycle.create_lifecycle_data_model(BuildModel.make(:cnb, app:))
            expect(data_model.stack).to eq(app.lifecycle_data.stack)
          end
        end
      end
    end

    describe '#staging_stack' do
      context 'when the user specifies a stack' do
        before do
          staging_message.buildpack_data.stack = 'cool-stack'
        end

        it 'is whatever has been requested in the staging message' do
          expect(cnb_lifecycle.staging_stack).to eq('cool-stack')
        end
      end

      context 'when the user does not specify a stack' do
        context 'and the app has a stack' do
          before do
            app.cnb_lifecycle_data = CNBLifecycleDataModel.make(app: app, stack: 'cooler-stack')
          end

          it 'uses the value set on the app' do
            expect(cnb_lifecycle.staging_stack).to eq('cooler-stack')
          end
        end

        context 'when the app does not have a stack' do
          it 'uses the default value for stack' do
            expect(cnb_lifecycle.staging_stack).to eq(app.lifecycle_data.stack)
          end
        end
      end
    end

    describe '#buildpack_infos' do
      let(:stubbed_data) { { stack: app.lifecycle_data.stack, buildpack_infos: [instance_double(BuildpackInfo)] } }
      let(:request_data) do
        {
          buildpacks: %w[docker://cool-buildpack docker://rad-buildpack]
        }
      end

      it 'returns the expected value' do
        expect(cnb_lifecycle.buildpack_infos).to have(2).items

        expect(cnb_lifecycle.buildpack_infos[0].buildpack_url).to eq('docker://cool-buildpack')
        expect(cnb_lifecycle.buildpack_infos[1].buildpack_url).to eq('docker://rad-buildpack')
      end
    end
  end
end
