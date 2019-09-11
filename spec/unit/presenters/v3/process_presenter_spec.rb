require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ProcessPresenter do
    describe '#to_hash' do
      let(:app_model) { VCAP::CloudController::AppModel.make }
      let(:health_check_type) { 'http' }
      let(:process) {
        VCAP::CloudController::ProcessModel.make(
          diego:                true,
          app_guid:             app_model.guid,
          instances:            3,
          memory:               42,
          disk_quota:           37,
          command:              'rackup',
          metadata:             {},
          health_check_type:    health_check_type,
          health_check_timeout: 51,
          health_check_http_endpoint: '/healthcheck',
          created_at:           Time.at(1)
        )
      }
      let(:result) { ProcessPresenter.new(process).to_hash }
      let(:links) do {
          self: { href: "#{link_prefix}/v3/processes/#{process.guid}" },
          scale: { href: "#{link_prefix}/v3/processes/#{process.guid}/actions/scale", method: 'POST' },
          app: { href: "#{link_prefix}/v3/apps/#{app_model.guid}" },
          space: { href: "#{link_prefix}/v3/spaces/#{process.space_guid}" },
          stats: { href: "#{link_prefix}/v3/processes/#{process.guid}/stats" },
        }
      end

      let!(:release_label) do
        VCAP::CloudController::ProcessLabelModel.make(
          key_name: 'release',
          value: 'stable',
          resource_guid: process.guid
        )
      end

      let!(:potato_label) do
        VCAP::CloudController::ProcessLabelModel.make(
          key_prefix: 'canberra.au',
          key_name: 'potato',
          value: 'mashed',
          resource_guid: process.guid
        )
      end

      let!(:mountain_annotation) do
        VCAP::CloudController::ProcessAnnotationModel.make(
          key: 'altitude',
          value: '14,412',
          resource_guid: process.guid,
        )
      end

      let!(:plain_annotation) do
        VCAP::CloudController::ProcessAnnotationModel.make(
          key: 'maize',
          value: 'hfcs',
          resource_guid: process.guid,
        )
      end

      before do
        process.updated_at = Time.at(2)
      end

      context 'when the process does not have a start command' do
        let(:droplet) do
          VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'detected-start-command' })
        end

        before do
          app_model.update(droplet: droplet)
          process.update(command: nil)
        end

        it 'shows the detected_start_command' do
          expect(result[:command]).to eq('detected-start-command')
        end
      end

      context('when health_check_type is http') do
        it 'presents the process as a hash' do
          expect(result[:guid]).to eq(process.guid)
          expect(result[:instances]).to eq(3)
          expect(result[:memory_in_mb]).to eq(42)
          expect(result[:disk_in_mb]).to eq(37)
          expect(result[:command]).to eq('rackup')
          expect(result[:health_check][:type]).to eq(health_check_type)
          expect(result[:health_check][:data][:timeout]).to eq(51)
          expect(result[:health_check][:data][:endpoint]).to eq('/healthcheck')
          expect(result[:created_at]).to eq('1970-01-01T00:00:01Z')
          expect(result[:updated_at]).to eq('1970-01-01T00:00:02Z')
          expect(result[:relationships][:app][:data][:guid]).to eq(app_model.guid)
          expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
          expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
          expect(result[:links]).to eq(links)
        end
      end

      context('when health_check_type is port') do
        let(:health_check_type) { 'port' }
        it 'presents the process as a hash without a health_check/data/endpoint' do
          expect(result[:guid]).to eq(process.guid)
          expect(result[:instances]).to eq(3)
          expect(result[:memory_in_mb]).to eq(42)
          expect(result[:disk_in_mb]).to eq(37)
          expect(result[:command]).to eq('rackup')
          expect(result[:health_check][:type]).to eq(health_check_type)
          expect(result[:health_check][:data][:timeout]).to eq(51)
          expect(result[:health_check][:data]).to_not have_key(:endpoint)
          expect(result[:created_at]).to eq('1970-01-01T00:00:01Z')
          expect(result[:updated_at]).to eq('1970-01-01T00:00:02Z')
          expect(result[:relationships][:app][:data][:guid]).to eq(app_model.guid)
          expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
          expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
          expect(result[:links]).to eq(links)
        end
      end

      describe '#revisions' do
        context('when the process has a revision') do
          let(:revision) { VCAP::CloudController::RevisionModel.make }
          before do
            process.revision = revision
          end
          it 'shows the revision in a data/guid block' do
            expect(result[:relationships][:revision]).to be_a_response_like({ data: { guid: revision.guid } })
          end
        end

        context('when the process does not have a revision') do
          it 'presents the revision as nil' do
            expect(result[:relationships].fetch(:revision)).to be_nil
          end
        end
      end

      context 'when show_secrets is false' do
        let(:result) { ProcessPresenter.new(process, show_secrets: false).to_hash }

        it 'redacts command' do
          expect(result[:command]).to eq('[PRIVATE DATA HIDDEN]')
        end
      end
    end
  end
end
