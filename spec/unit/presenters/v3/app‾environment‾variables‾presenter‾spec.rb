require 'spec_helper'
require 'presenters/v3/app_environment_variables_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppEnvironmentVariablesPresenter do
    let(:app) do
      VCAP::CloudController::AppModel.make(
        environment_variables: { 'CUSTOM_ENV_VAR' => 'hello' },
      )
    end

    subject(:presenter) { AppEnvironmentVariablesPresenter.new(app) }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the app environment variables as json' do
        expect(result).to eq({
          var: {
            CUSTOM_ENV_VAR: 'hello'
          },
          links: {
            self: {
              href: "#{link_prefix}/v3/apps/#{app.guid}/environment_variables",
            },
            app: {
              href: "#{link_prefix}/v3/apps/#{app.guid}",
            }
          }
        })
      end
    end
  end
end
