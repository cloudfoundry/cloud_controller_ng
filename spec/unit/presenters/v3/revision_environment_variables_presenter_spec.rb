require 'spec_helper'
require 'presenters/v3/revision_environment_variables_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RevisionEnvironmentVariablesPresenter do
    let(:revision) do
      VCAP::CloudController::RevisionModel.make(
        environment_variables: { 'CUSTOM_ENV_VAR' => 'hello' },
      )
    end

    subject(:presenter) { RevisionEnvironmentVariablesPresenter.new(revision) }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the app environment variables as json' do
        expect(result).to eq({
          var: {
            CUSTOM_ENV_VAR: 'hello'
          },
          links: {
            self: {
              href: "#{link_prefix}/v3/revisions/#{revision.guid}/environment_variables",
            },
            revision: {
              href: "#{link_prefix}/v3/revisions/#{revision.guid}",
            },
            app: {
              href: "#{link_prefix}/v3/apps/#{revision.app.guid}",
            },
          }
        })
      end
    end
  end
end
