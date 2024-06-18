require 'spec_helper'
require 'cloud_controller/diego/lifecycles/app_cnb_lifecycle'
require_relative 'app_lifecycle_shared'

module VCAP::CloudController
  RSpec.describe AppCNBLifecycle do
    subject(:lifecycle) { AppCNBLifecycle.new(message) }
    let(:message) { VCAP::CloudController::AppCreateMessage.new(request) }
    let(:request) { { lifecycle: { type: 'cnb', data: lifecycle_request_data } } }
    let(:lifecycle_request_data) { { buildpacks: ['http://acme.com'] } }

    it_behaves_like 'a app lifecycle'

    describe '#create_lifecycle_data_model' do
      let!(:app) { AppModel.make }

      it 'creates CNBLifecycleDataModel' do
        expect do
          lifecycle.create_lifecycle_data_model(app)
        end.to change(CNBLifecycleDataModel, :count).by(1)
      end

      describe 'defaults' do
        context 'when a buildpack is not requested' do
          let(:lifecycle_request_data) { {} }

          it 'sets buildpack to nil' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpacks).to eq []
          end
        end

        context 'when the user requested a buildpack with tag' do
          let(:lifecycle_request_data) { { buildpacks: ['docker://custom-bp:latest'] } }

          it 'uses the requested buildpack as url' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpacks).to eq(['docker://custom-bp:latest'])
          end
        end

        context 'when the user requests multiple buildpacks' do
          let(:lifecycle_request_data) { { buildpacks: ['docker://nodejs', 'http://buildpack.com', 'http://other.com'] } }

          before do
            Buildpack.make(name: 'custom-bp')
          end

          it 'uses all of the buildpacks' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpacks).to eq(['docker://nodejs', 'http://buildpack.com', 'http://other.com'])
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
      let(:lifecycle_request_data) { { buildpacks: ['http://oj.com', 'http://acme.com'], stack: 'sweetness' } }

      it 'updates the CNBLifecycleDataModel' do
        lifecycle.update_lifecycle_data_model(app)

        data_model = app.lifecycle_data

        expect(data_model.buildpacks).to eq(['http://oj.com', 'http://acme.com'])
        expect(data_model.stack).to eq('sweetness')
      end
    end

    describe '#validation' do
      context 'with no buildpacks' do
        let(:lifecycle_request_data) { {} }

        it 'invalid' do
          expect(lifecycle.valid?).to be(false)
        end
      end

      context 'with buildpacks' do
        let(:lifecycle_request_data) { { buildpacks: %w[foo bar] } }

        it 'valid' do
          expect(lifecycle.valid?).to be(true)
        end
      end
    end
  end
end
