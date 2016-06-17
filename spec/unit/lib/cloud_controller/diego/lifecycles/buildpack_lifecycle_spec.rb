require 'spec_helper'
require_relative 'lifecycle_shared'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycle do
    let!(:package) { PackageModel.make(type: PackageModel::BITS_TYPE) }
    let(:staging_message) { DropletCreateMessage.new(lifecycle: { data: request_data, type: 'buildpack' }) }
    let(:request_data) { {} }

    subject(:buildpack_lifecycle) { BuildpackLifecycle.new(package, staging_message) }

    it_behaves_like 'a lifecycle'

    describe '#create_lifecycle_data_model' do
      let(:request_data) do
        {
          buildpack: 'cool-buildpack',
          stack:     'cool-stack'
        }
      end

      it 'can create a BuildpackLifecycleDataModel' do
        droplet = DropletModel.make

        expect {
          buildpack_lifecycle.create_lifecycle_data_model(droplet)
        }.to change(VCAP::CloudController::BuildpackLifecycleDataModel, :count).by(1)

        data_model = VCAP::CloudController::BuildpackLifecycleDataModel.last

        expect(data_model.buildpack).to eq('cool-buildpack')
        expect(data_model.stack).to eq('cool-stack')
        expect(data_model.droplet).to eq(droplet)
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
            BuildpackLifecycleDataModel.make(app: package.app)
          end

          it 'uses the value set on the app' do
            expect(buildpack_lifecycle.staging_stack).to eq(package.app.buildpack_lifecycle_data.stack)
          end
        end

        context 'and the app does not have a stack' do
          before do
            BuildpackLifecycleDataModel.make(app: package.app, stack: nil)
          end

          it 'uses the default value for stack' do
            expect(buildpack_lifecycle.staging_stack).to eq(Stack.default.name)
          end
        end
      end
    end

    describe 'pre-known receipt information' do
      let(:app_buildpack) { Buildpack.make }
      let(:staging_buildpack) { Buildpack.make }
      let(:app) { AppModel.make }
      let(:package) { PackageModel.make(app_guid: app.guid) }

      describe 'buildpack_receipt_buildpack_guid' do
        context 'when the buildpack is in the system' do
          context 'and specified by the app' do
            let(:staging_message) { DropletCreateMessage.new }

            before do
              BuildpackLifecycleDataModel.make(app: app, buildpack: app_buildpack.name)
            end

            it 'is the guid of the app buildpack' do
              receipt = buildpack_lifecycle.pre_known_receipt_information
              expect(receipt[:buildpack_receipt_buildpack_guid]).to eq(app_buildpack.guid)
            end
          end

          context 'and specified by the staging message even if specified by the app' do
            let(:staging_message) do
              DropletCreateMessage.new(lifecycle: { data: { buildpack: staging_buildpack.name }, type: 'buildpack' })
            end

            before do
              BuildpackLifecycleDataModel.make(app: app, buildpack: app_buildpack.name)
            end

            it 'is the guid of the staging message buildpack' do
              receipt = buildpack_lifecycle.pre_known_receipt_information
              expect(receipt[:buildpack_receipt_buildpack_guid]).to eq(staging_buildpack.guid)
            end
          end
        end

        context 'when the buildpack is not in the system' do
          let(:staging_message) do
            DropletCreateMessage.new(lifecycle: { data: { buildpack: 'git://cool-buildpack' }, type: 'buildpack' })
          end

          it 'is nil' do
            receipt = buildpack_lifecycle.pre_known_receipt_information
            expect(receipt[:buildpack_receipt_buildpack_guid]).to be_nil
          end
        end
      end

      describe 'buildpack_receipt_stack_name' do
        let(:staging_message) do
          DropletCreateMessage.new(lifecycle: { data: { stack: 'pancake' }, type: 'buildpack' })
        end

        it 'is the requested stack' do
          receipt = buildpack_lifecycle.pre_known_receipt_information
          expect(receipt[:buildpack_receipt_stack_name]).to eq('pancake')
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
