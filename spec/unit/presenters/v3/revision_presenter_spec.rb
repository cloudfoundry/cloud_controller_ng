require 'spec_helper'
require 'presenters/v3/revision_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RevisionPresenter do
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:revision) { VCAP::CloudController::RevisionModel.make(app: app, version: 300, droplet_guid: 'some-guid') }

    describe '#to_hash' do
      it 'presents the revision as json' do
        result = RevisionPresenter.new(revision).to_hash
        links = {
          self: { href: "#{link_prefix}/v3/apps/#{app.guid}/revisions/#{revision.guid}" },
        }

        expect(result[:guid]).to eq(revision.guid)
        expect(result[:droplet][:guid]).to eq(revision.droplet_guid)
        expect(result[:version]).to eq(revision.version)
        expect(result[:created_at]).to be_a(Time)
        expect(result[:updated_at]).to be_a(Time)
        expect(result[:links]).to eq(links)
      end
    end
  end
end
