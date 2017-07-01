require 'spec_helper'
require_relative 'lifecycle_shared'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycle do
    let(:app) { AppModel.create(name: 'some-app', space: Space.make) }
    let!(:package) { PackageModel.make(type: PackageModel::BITS_TYPE, app: app) }
    let(:staging_message) { BuildCreateMessage.new(lifecycle: { data: request_data, type: 'buildpack' }) }
    let(:request_data) { {} }

    subject(:buildpack_lifecycle) { BuildpackLifecycle.new(package, staging_message) }

    it_behaves_like 'a lifecycle'

    describe '#create_lifecycle_data_model' do
      let(:request_data) do
        {
          buildpacks: ['cool-buildpack'],
        }
      end

      it 'can create a BuildpackLifecycleDataModel' do
        build = BuildModel.make

        expect {
          buildpack_lifecycle.create_lifecycle_data_model(build)
        }.to change(VCAP::CloudController::BuildpackLifecycleDataModel, :count).by(1)

        data_model = VCAP::CloudController::BuildpackLifecycleDataModel.last

        expect(data_model.buildpacks).to eq(['cool-buildpack'])
        expect(data_model.build).to eq(build)
      end

      context 'when the user specifies a stack' do
        let(:request_data) do
          { stack: 'cool-stack' }
        end

        it 'uses that stack' do
          data_model = buildpack_lifecycle.create_lifecycle_data_model(BuildModel.make)
          expect(data_model.stack).to eq('cool-stack')
        end
      end

      context 'when the user does not specify a stack' do
        let(:request_data) { {} }

        context 'when the app has a stack' do
          before do
            BuildpackLifecycleDataModel.make(app: app, stack: 'best-stack')
          end

          it 'uses the stack from the app' do
            data_model = buildpack_lifecycle.create_lifecycle_data_model(BuildModel.make)
            expect(data_model.stack).to eq('best-stack')
          end
        end

        context 'when the app does not have a stack' do
          it 'uses the default stack' do
            data_model = buildpack_lifecycle.create_lifecycle_data_model(BuildModel.make)
            expect(data_model.stack).to eq(Stack.default.name)
          end
        end
      end
    end

    it 'provides staging environment variables' do
      staging_message.buildpack_data.stack = 'cool-stack'

      expect(buildpack_lifecycle.staging_environment_variables).to eq({
        'CF_STACK' => 'cool-stack'
      })
    end

    describe 'the staging stack' do
      context 'when the user specifies a stack' do
        before do
          staging_message.buildpack_data.stack = 'cool-stack'
        end

        it 'is whatever has been requested in the staging message' do
          expect(buildpack_lifecycle.staging_stack).to eq('cool-stack')
        end
      end

      context 'when the user does not specify a stack' do
        context 'and the app has a stack' do
          before do
            BuildpackLifecycleDataModel.make(app: app, stack: 'cooler-stack')
          end

          it 'uses the value set on the app' do
            expect(buildpack_lifecycle.staging_stack).to eq('cooler-stack')
          end
        end

        context 'and the app does not have a stack' do
          it 'uses the default value for stack' do
            expect(buildpack_lifecycle.staging_stack).to eq(Stack.default.name)
          end
        end
      end
    end

    describe 'buildpack info' do
      it 'is provided' do
        expect(buildpack_lifecycle.buildpack_info).to be_a(BuildpackInfo)
      end
    end

    describe 'validation' do
      let(:validator) { instance_double(BuildpackLifecycleDataValidator) }
      before do
        allow(validator).to receive(:valid?)
        allow(validator).to receive(:errors)
        allow(BuildpackLifecycleDataValidator).to receive(:new).and_return(validator)
      end

      it 'delegates #valid? to a BuildpackLifecycleDataValidator' do
        buildpack_lifecycle.valid?

        expect(validator).to have_received(:valid?)
      end

      it 'delegates #errors to a BuildpackLifecycleDataValidator' do
        buildpack_lifecycle.errors

        expect(validator).to have_received(:errors)
      end
    end
  end
end
