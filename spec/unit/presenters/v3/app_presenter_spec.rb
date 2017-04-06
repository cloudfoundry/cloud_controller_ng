require 'spec_helper'
require 'presenters/v3/app_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppPresenter do
    let(:app) do
      VCAP::CloudController::AppModel.make(
        environment_variables: { 'some' => 'stuff' },
        desired_state: 'STOPPED',
      )
    end

    before do
      app.lifecycle_data.update(
        buildpack: 'git://user:pass@github.com/repo',
        stack: 'the-happiest-stack',
      )
    end

    describe '#to_hash' do
      let(:result) { AppPresenter.new(app).to_hash }

      it 'presents the app as json' do
        app.add_process({ app: app, instances: 4 })

        links = {
          self: { href: "#{link_prefix}/v3/apps/#{app.guid}" },
          space: { href: "#{link_prefix}/v2/spaces/#{app.space_guid}" },
          processes: { href: "#{link_prefix}/v3/apps/#{app.guid}/processes" },
          route_mappings: { href: "#{link_prefix}/v3/apps/#{app.guid}/route_mappings" },
          packages: { href: "#{link_prefix}/v3/apps/#{app.guid}/packages" },
          current_droplet: { href: "#{link_prefix}/v3/apps/#{app.guid}/droplets/current" },
          droplets: { href: "#{link_prefix}/v3/apps/#{app.guid}/droplets" },
          tasks: { href: "#{link_prefix}/v3/apps/#{app.guid}/tasks" },
          start: { href: "#{link_prefix}/v3/apps/#{app.guid}/start", method: 'PUT' },
          stop: { href: "#{link_prefix}/v3/apps/#{app.guid}/stop", method: 'PUT' },
          environment_variables: { href: "#{link_prefix}/v3/apps/#{app.guid}/environment_variables" },
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
        expect(result[:lifecycle][:data][:buildpacks]).to eq(['git://***:***@github.com/repo'])
      end
    end
  end
end
