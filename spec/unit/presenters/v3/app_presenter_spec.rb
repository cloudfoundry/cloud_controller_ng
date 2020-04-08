require 'spec_helper'
require 'presenters/v3/app_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppPresenter do
    let(:app) do
      VCAP::CloudController::AppModel.make(
        name: 'Davis',
        environment_variables: { 'some' => 'stuff' },
        desired_state: 'STOPPED',
      )
    end

    before do
      VCAP::CloudController::Buildpack.make(name: 'limabean')
      app.lifecycle_data.update(
        buildpacks: ['git://user:pass@github.com/repo', 'limabean'],
        stack: 'the-happiest-stack',
      )
    end

    describe '#to_hash' do
      let(:result) { AppPresenter.new(app).to_hash }

      it 'presents the app as json' do
        app.add_process({ app: app, instances: 4 })

        links = {
          self: { href: "#{link_prefix}/v3/apps/#{app.guid}" },
          space: { href: "#{link_prefix}/v3/spaces/#{app.space_guid}" },
          processes: { href: "#{link_prefix}/v3/apps/#{app.guid}/processes" },
          packages: { href: "#{link_prefix}/v3/apps/#{app.guid}/packages" },
          current_droplet: { href: "#{link_prefix}/v3/apps/#{app.guid}/droplets/current" },
          droplets: { href: "#{link_prefix}/v3/apps/#{app.guid}/droplets" },
          tasks: { href: "#{link_prefix}/v3/apps/#{app.guid}/tasks" },
          start: { href: "#{link_prefix}/v3/apps/#{app.guid}/actions/start", method: 'POST' },
          stop: { href: "#{link_prefix}/v3/apps/#{app.guid}/actions/stop", method: 'POST' },
          environment_variables: { href: "#{link_prefix}/v3/apps/#{app.guid}/environment_variables" },
          revisions: { href: "#{link_prefix}/v3/apps/#{app.guid}/revisions" },
          deployed_revisions: { href: "#{link_prefix}/v3/apps/#{app.guid}/revisions/deployed" },
          features: { href: "#{link_prefix}/v3/apps/#{app.guid}/features" },
        }

        expect(result[:guid]).to eq(app.guid)
        expect(result[:name]).to eq(app.name)
        expect(result[:state]).to eq(app.desired_state)
        expect(result[:environment_variables]).to be_nil
        expect(result[:created_at]).to be_a(Time)
        expect(result[:updated_at]).to be_a(Time)
        expect(result[:links]).to eq(links)
        expect(result[:lifecycle][:type]).to eq('buildpack')
        expect(result[:lifecycle][:data][:stack]).to eq('the-happiest-stack')
        expect(result[:lifecycle][:data][:buildpacks]).to eq(['git://***:***@github.com/repo', 'limabean'])
        expect(result[:relationships][:space][:data][:guid]).to eq(app.space.guid)
        expect(result[:metadata][:labels]).to eq({})
        expect(result[:metadata][:annotations]).to eq({})
      end

      context 'when there are labels and annotations for the app' do
        let!(:release_label) do
          VCAP::CloudController::AppLabelModel.make(
            key_name: 'release',
            value: 'stable',
            resource_guid: app.guid
          )
        end

        let!(:potato_label) do
          VCAP::CloudController::AppLabelModel.make(
            key_prefix: 'maine.gov',
            key_name: 'potato',
            value: 'mashed',
            resource_guid: app.guid
          )
        end

        let!(:annotation) do
          VCAP::CloudController::AppAnnotationModel.make(
            resource_guid: app.guid,
            key: 'contacts',
            value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
          )
        end

        it 'includes the metadata on the presented app' do
          expect(result[:guid]).to eq(app.guid)
          expect(result[:name]).to eq(app.name)
          expect(result[:metadata][:labels]).to eq('release' => 'stable', 'maine.gov/potato' => 'mashed')
          expect(result[:metadata][:annotations]).to eq('contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)')
        end
      end

      context 'when there are decorators' do
        let(:banana_decorator) do
          Class.new do
            class << self
              def decorate(hash, apps)
                hash[:included] ||= {}
                hash[:included][:bananas] = apps.map { |app| "#{app.name} is bananas" }
                hash
              end
            end
          end
        end

        let(:result) { AppPresenter.new(app, decorators: [banana_decorator]).to_hash }

        it 'runs the decorators' do
          expect(result[:included][:bananas]).to match_array(['Davis is bananas'])
        end
      end
    end
  end
end
