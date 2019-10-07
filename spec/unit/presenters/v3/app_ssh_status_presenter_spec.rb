require 'spec_helper'
require 'presenters/v3/app_ssh_status_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppSshStatusPresenter do
    let!(:app) { VCAP::CloudController::AppModel.make(enable_ssh: true) }
    let(:globally_enabled) { TestConfig.config_instance.get(:allow_app_ssh_access) }

    before do
      app.space.update(allow_ssh: true)
      TestConfig.override(allow_app_ssh_access: true)
    end

    describe '#to_hash' do
      context 'when ssh is globally disabled' do
        before do
          TestConfig.override(allow_app_ssh_access: false)
        end

        it 'presents ssh status as disabled globally' do
          result = AppSshStatusPresenter.new(app, globally_enabled).to_hash
          expect(result[:enabled]).to eq(false)
          expect(result[:reason]).to eq('ssh is disabled globally')
        end
      end

      context 'when ssh is globally enabled' do
        it 'presents ssh status as disabled for space when ssh is space disabled' do
          app.space.update(allow_ssh: false)

          result = AppSshStatusPresenter.new(app, globally_enabled).to_hash
          expect(result[:enabled]).to eq(false)
          expect(result[:reason]).to eq("ssh is disabled for space '#{app.space.name}'")
        end

        context 'and ssh is space enabled' do
          it 'presents ssh status as disabled when ssh is disabled for the app' do
            app.update(enable_ssh: false)

            result = AppSshStatusPresenter.new(app, globally_enabled).to_hash
            expect(result[:enabled]).to eq(false)
            expect(result[:reason]).to eq('ssh is disabled for app')
          end

          it 'presents ssh status as enabled when ssh is enabled for the app' do
            result = AppSshStatusPresenter.new(app, globally_enabled).to_hash
            expect(result[:enabled]).to eq(true)
            expect(result[:reason]).to eq('')
          end
        end
      end
    end
  end
end
