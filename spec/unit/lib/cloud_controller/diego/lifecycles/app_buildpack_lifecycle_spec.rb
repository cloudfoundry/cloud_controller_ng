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
    it_behaves_like 'custom-stack lifecycle updates', 'buildpack', 'https://example.com/buildpack.zip'

    describe '#create_lifecycle_data_model' do
      let!(:app) { create(:app_model) }

      it 'creates BuildpackLifecycleDataModel' do
        expect do
          lifecycle.create_lifecycle_data_model(app)
        end.to change(BuildpackLifecycleDataModel, :count).by(1)
      end

      describe 'defaults' do
        context 'when a buildpack is not requested' do
          let(:lifecycle_request_data) { {} }

          it 'sets buildpack to nil' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpacks).to eq []
          end
        end

        context 'when the user requested a buildpack' do
          let(:lifecycle_request_data) { { buildpacks: ['custom-bp'] } }

          before do
            create(:buildpack, name: 'custom-bp')
          end

          it 'uses the requested buildpack' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpacks).to eq(['custom-bp'])
          end
        end

        context 'when the user requests multiple buildpacks' do
          let(:lifecycle_request_data) { { buildpacks: ['custom-bp', 'http://buildpack.com', 'http://other.com'] } }

          before do
            create(:buildpack, name: 'custom-bp')
          end

          it 'uses all of the buildpacks' do
            lifecycle_data_model = lifecycle.create_lifecycle_data_model(app)
            expect(lifecycle_data_model.buildpacks).to eq(['custom-bp', 'http://buildpack.com', 'http://other.com'])
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
      let(:app) { create(:app_model) }
      let!(:ruby_buildpack) { create(:buildpack, name: 'ruby_buildpack') }
      let(:lifecycle_request_data) { { buildpacks: ['http://oj.com', 'ruby_buildpack'], stack: 'sweetness' } }

      it 'updates the BuildpackLifecycleDataModel' do
        lifecycle.update_lifecycle_data_model(app)

        data_model = app.lifecycle_data

        expect(data_model.buildpacks).to eq(['http://oj.com', 'ruby_buildpack'])
        expect(data_model.stack).to eq('sweetness')
      end
    end

    describe 'validation' do
      let(:validator) { instance_double(BuildpackLifecycleDataValidator) }
      let(:stubbed_fetcher_data) { { stack: 'foo', buildpack_infos: [] } }

      before do
        allow(validator).to receive(:valid?)
        allow(validator).to receive(:errors)

        allow(BuildpackLifecycleFetcher).to receive(:fetch).and_return(stubbed_fetcher_data)
        allow(BuildpackLifecycleDataValidator).to receive(:new).and_return(validator)
      end

      it 'constructs the validator correctly' do
        lifecycle.valid?

        expect(BuildpackLifecycleDataValidator).to have_received(:new).with(
          buildpack_infos: [],
          stack: 'foo',
          stack_name: Stack.default.name,
          lifecycle_type: Lifecycles::BUILDPACK,
          credentials: nil,
          credentials_from_message: false
        )
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

    describe 'validation of stored lifecycle data' do
      let(:stored_stack) { create(:stack, name: 'some-stack') }
      let(:app) { create(:app_model, :buildpack) }
      let!(:stored_buildpack) { create(:buildpack, name: 'some-buildpack', stack: stored_stack.name) }

      before do
        app.lifecycle_data.update(buildpacks: ['some-buildpack'], stack: stored_stack.name)
      end

      context 'when the request does not include lifecycle data' do
        let(:message) { AppUpdateMessage.new(lifecycle: { type: 'buildpack', data: {} }) }

        it 'does not validate stored buildpacks' do
          expect(BuildpackLifecycleFetcher).to receive(:fetch).with([], Stack.default.name, Lifecycles::BUILDPACK).and_call_original

          lifecycle = AppBuildpackLifecycle.new(message, app)

          expect(lifecycle).to be_valid
        end
      end

      context 'when the request clears lifecycle credentials' do
        let(:message) { AppUpdateMessage.new(lifecycle: { type: 'buildpack', data: { credentials: nil } }) }

        it 'does not validate stored buildpacks' do
          expect(BuildpackLifecycleFetcher).to receive(:fetch).with([], Stack.default.name, Lifecycles::BUILDPACK).and_call_original

          lifecycle = AppBuildpackLifecycle.new(message, app)

          expect(lifecycle).to be_valid
        end
      end

      context 'when credentials are updated without buildpacks' do
        let(:message) do
          AppUpdateMessage.new(lifecycle: {
                                 type: 'buildpack',
                                 data: { credentials: { 'buildpacks.example.org' => { username: 'user', password: 'password' } } }
                               })
        end

        it 'validates the stored buildpacks against the stored stack' do
          expect(BuildpackLifecycleFetcher).to receive(:fetch).with(['some-buildpack'], stored_stack.name, Lifecycles::BUILDPACK).and_call_original

          lifecycle = AppBuildpackLifecycle.new(message, app)

          expect(lifecycle).to be_valid
        end
      end
    end

    describe '#create_lifecycle_data_model with credentials' do
      context 'when credentials are provided' do
        let(:creds) { { 'git.example.com' => { 'username' => 'u', 'password' => 'p' } } }
        let(:lifecycle_request_data) { { buildpacks: ['http://git.example.com/acme/bp.git'], credentials: creds } }
        let!(:app) { create(:app_model) }

        it 'stores credentials on the lifecycle data model' do
          lifecycle.create_lifecycle_data_model(app)
          expect(app.buildpack_lifecycle_data.reload.credentials).to eq(creds)
        end
      end
    end

    describe '#update_lifecycle_data_model credentials handling' do
      let(:app) { create(:app_model, :buildpack) }

      context 'when credentials are requested' do
        let(:creds) { { 'git.example.com' => { 'username' => 'u', 'password' => 'p' } } }
        let(:message) { AppUpdateMessage.new({ lifecycle: { type: 'buildpack', data: { credentials: creds } } }) }

        it 'updates the credentials on the lifecycle data' do
          lifecycle.update_lifecycle_data_model(app)
          expect(app.buildpack_lifecycle_data.reload.credentials).to eq(creds)
        end
      end

      context 'when credentials are set to null (clear)' do
        let(:message) { AppUpdateMessage.new({ lifecycle: { type: 'buildpack', data: { credentials: nil } } }) }

        before do
          app.buildpack_lifecycle_data.update(credentials_json: Oj.dump({ 'git.example.com' => { 'username' => 'u' } }))
        end

        it 'clears the credentials' do
          lifecycle.update_lifecycle_data_model(app)
          expect(app.buildpack_lifecycle_data.reload.credentials).to be_nil
        end
      end

      context 'when credentials are absent from the request (not requested)' do
        let(:message) { AppUpdateMessage.new({ lifecycle: { type: 'buildpack', data: { stack: app.buildpack_lifecycle_data.stack } } }) }

        before do
          stored_creds = { 'git.example.com' => { 'username' => 'stored' } }
          app.buildpack_lifecycle_data.update(credentials_json: Oj.dump(stored_creds))
        end

        it 'leaves stored credentials untouched' do
          lifecycle.update_lifecycle_data_model(app)
          expect(app.buildpack_lifecycle_data.reload.credentials).to eq({ 'git.example.com' => { 'username' => 'stored' } })
        end
      end

      context 'when PATCH sends only credentials and stored buildpack URL has userinfo' do
        let(:app) { create(:app_model, :buildpack) }
        let(:creds) { { 'git.example.com' => { 'username' => 'u', 'password' => 'p' } } }
        let(:message) { AppUpdateMessage.new({ lifecycle: { type: 'buildpack', data: { credentials: creds } } }) }

        before do
          app.buildpack_lifecycle_data.update(buildpacks: ['https://user:pass@git.example.com/bp.git'])
        end

        it 'is invalid because stored buildpack URL already has userinfo' do
          lc = AppBuildpackLifecycle.new(message, app)
          expect(lc.valid?).to be false
          expect(lc.errors.full_messages.join).to match(/credentials/)
        end
      end

      context 'when the request submits a buildpack URL with userinfo and the app has stored credentials' do
        let(:app) { create(:app_model, :buildpack) }
        let(:message) { AppUpdateMessage.new({ lifecycle: { type: 'buildpack', data: { buildpacks: ['https://user:pass@git.example.com/bp.git'] } } }) }

        before do
          app.buildpack_lifecycle_data.credentials = { 'git.example.com' => { 'username' => 'stored', 'password' => 'stored' } }
          app.buildpack_lifecycle_data.save
        end

        it 'is invalid and explains how to clear the stored credentials' do
          lc = AppBuildpackLifecycle.new(message, app)
          expect(lc.valid?).to be false
          expect(lc.errors.full_messages.join).to include('already has stored buildpack credentials')
          expect(lc.errors.full_messages.join).to include('credentials: null')
        end
      end

      context 'when the app is currently a docker app' do
        let(:app) { create(:app_model, :docker) }
        let(:message) { AppUpdateMessage.new({ lifecycle: { type: 'buildpack', data: {} } }) }

        it 'does not raise when resolving credentials from docker lifecycle data' do
          expect { AppBuildpackLifecycle.new(message, app) }.not_to raise_error
        end
      end
    end
  end
end
