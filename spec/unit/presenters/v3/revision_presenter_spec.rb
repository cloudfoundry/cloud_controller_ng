require 'spec_helper'
require 'presenters/v3/revision_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RevisionPresenter do
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:revision) { VCAP::CloudController::RevisionModel.make(app: app, version: 300, droplet_guid: 'some-guid') }

    let!(:release_label) do
      VCAP::CloudController::RevisionLabelModel.make(
        key_name: 'release',
        value: 'stable',
        resource_guid: revision.guid
      )
    end

    let!(:potato_label) do
      VCAP::CloudController::RevisionLabelModel.make(
        key_prefix: 'canberra.au',
        key_name: 'potato',
        value: 'mashed',
        resource_guid: revision.guid
      )
    end

    let!(:mountain_annotation) do
      VCAP::CloudController::RevisionAnnotationModel.make(
        key: 'altitude',
        value: '14,412',
        resource_guid: revision.guid,
      )
    end

    let!(:plain_annotation) do
      VCAP::CloudController::RevisionAnnotationModel.make(
        key: 'maize',
        value: 'hfcs',
        resource_guid: revision.guid,
      )
    end

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
        expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
        expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
      end
    end
  end
end
