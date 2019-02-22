require 'spec_helper'
require 'presenters/v3/revision_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RevisionPresenter do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:revision) do
      VCAP::CloudController::RevisionModel.make(
        app: app_model,
        version: 300,
        droplet_guid: 'some-guid'
      )
    end

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

    before do
      revision.add_command_for_process_type('web', './start')
      revision.add_command_for_process_type('worker', nil)
    end

    describe '#to_hash' do
      it 'presents the revision as json' do
        result = RevisionPresenter.new(revision).to_hash
        links = {
          self: { href: "#{link_prefix}/v3/revisions/#{revision.guid}" },
          app:  { href: "#{link_prefix}/v3/apps/#{app_model.guid}" },
        }
        expect(result[:guid]).to eq(revision.guid)
        expect(result[:droplet][:guid]).to eq(revision.droplet_guid)
        expect(result[:relationships][:app][:data][:guid]).to eq(app_model.guid)
        expect(result[:version]).to eq(revision.version)
        expect(result[:created_at]).to be_a(Time)
        expect(result[:updated_at]).to be_a(Time)
        expect(result[:links]).to eq(links)
        expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
        expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
        expect(result[:processes]['web']).to eq('command' => './start')
        expect(result[:processes]['worker']).to eq('command' => nil)
      end
    end
  end
end
