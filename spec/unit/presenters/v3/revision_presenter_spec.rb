require 'spec_helper'
require 'presenters/v3/revision_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RevisionPresenter do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:droplet) do
      VCAP::CloudController::DropletModel.make(
        app: app_model,
        process_types: {
          'web' => 'droplet_web_command',
          'worker' => 'droplet_worker_command',
        })
    end
    let(:revision) do
      VCAP::CloudController::RevisionModel.make(:custom_web_command,
        app: app_model,
        version: 300,
        droplet_guid: droplet.guid,
        description: 'Initial revision'
      )
    end

    let!(:revision_sidecar) do
      VCAP::CloudController::RevisionSidecarModel.make(
        revision: revision,
        name: 'my-sidecar',
        command: 'bake rackup',
        memory: 300
      )
    end

    let!(:revision_web_process_command2) do
      VCAP::CloudController::RevisionProcessCommandModel.make(
        revision_guid: revision.guid,
        process_type: 'non_droplet_worker',
        process_command: './work'
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

    describe '#to_hash' do
      it 'presents the revision as json' do
        result = RevisionPresenter.new(revision).to_hash
        links = {
          self: { href: "#{link_prefix}/v3/revisions/#{revision.guid}" },
          app:  { href: "#{link_prefix}/v3/apps/#{app_model.guid}" },
          environment_variables:  { href: "#{link_prefix}/v3/revisions/#{revision.guid}/environment_variables" },
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
        expect(result[:processes]['web']).to eq('command' => 'custom_web_command')
        expect(result[:processes]['worker']).to eq('command' => nil)
        expect(result[:processes]['non_droplet_worker']).to eq('command' => './work')
        expect(result[:sidecars][0][:name]).to eq('my-sidecar')
        expect(result[:sidecars][0][:command]).to eq('bake rackup')
        expect(result[:sidecars][0][:memory_in_mb]).to eq(300)
        expect(result[:sidecars][0][:process_types]).to eq(['web'])
        expect(result[:description]).to eq('Initial revision')
        expect(result[:deployable]).to eq(true)
      end

      context 'when the droplet is not staged' do
        let(:droplet) do
          VCAP::CloudController::DropletModel.make(
            app: app_model,
            state: VCAP::CloudController::DropletModel::EXPIRED_STATE,
            process_types: {
              'web' => 'droplet_web_command',
              'worker' => 'droplet_worker_command',
            })
        end

        it 'returns deployable is false' do
          result = RevisionPresenter.new(revision).to_hash
          expect(result[:deployable]).to eq(false)
        end
      end
    end
  end
end
