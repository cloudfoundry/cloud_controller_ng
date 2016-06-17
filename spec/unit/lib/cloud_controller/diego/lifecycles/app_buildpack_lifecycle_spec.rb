require 'spec_helper'
require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require_relative 'app_lifecycle_shared'

module VCAP::CloudController
  RSpec.describe AppBuildpackLifecycle do
    subject(:lifecycle) { AppBuildpackLifecycle.new(message) }
    let(:message) { VCAP::CloudController::AppCreateMessage.new(request) }
    let(:request) { { lifecycle: { type: 'buildpack', data: lifecycle_request_data } } }
    let(:lifecycle_request_data) { {} }

    it_behaves_like 'a app lifecycle'

    describe '#create_lifecycle_data_model' do
      let(:app) { AppModel.make }

      it 'creates BuildpackLifecycleDataModel' do
        expect {
          lifecycle.create_lifecycle_data_model(app)
        }.to change { BuildpackLifecycleDataModel.count }.by(1)
      end

      describe 'defaults' do
        context 'when a buildpack is not requested' do
          let(:lifecycle_request_data) { {} }

          it 'sets buildpack to nil' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpack).to be_nil
          end
        end

        context 'when the user requested a buildpack' do
          let(:lifecycle_request_data) { { buildpack: 'custom-bp' } }

          it 'uses the requested buildpack' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpack).to eq('custom-bp')
          end
        end

        context 'when the user requests a stack' do
          let(:lifecycle_request_data) { { stack: 'custom-stack' } }

          it 'uses the requested stack' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.stack).to eq('custom-stack')
          end

          context 'when the requested stack is nil' do
            let(:lifecycle_request_data) { { stack: nil } }

            it 'uses the default stack' do
              lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
              expect(lifecycle_data_model.stack).to eq(Stack.default.name)
            end
          end
        end

        context 'when the user does not request a stack' do
          let(:lifecycle_request_data) { {} }

          it 'uses the default stack' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.stack).to eq(Stack.default.name)
          end
        end
      end
    end

    describe '#update_lifecycle_data_model' do
      let(:app) { AppModel.make(:buildpack) }
      let(:lifecycle_request_data) { { buildpack: 'http://oj.com', stack: 'sweetness' } }

      it 'updates the BuildpackLifecycleDataModel' do
        lifecycle.update_lifecycle_data_model(app)

        data_model = app.lifecycle_data

        expect(data_model.buildpack).to eq('http://oj.com')
        expect(data_model.stack).to eq('sweetness')
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
        lifecycle.valid?
        expect(validator).to have_received(:valid?)
      end

      it 'delegates #errors to a BuildpackLifecycleDataValidator' do
        lifecycle.errors
        expect(validator).to have_received(:errors)
      end
    end
  end
end
