require 'spec_helper'
require 'presenters/v3/route_mapping_presenter'
require 'messages/route_mappings_list_message'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RouteDestinationsPresenter do
    subject(:presenter) { RouteDestinationsPresenter.new(route) }

    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:app_docker) { VCAP::CloudController::AppModel.make(:docker, droplet: droplet_docker) }
    let!(:app_docker_without_process) { VCAP::CloudController::AppModel.make(:docker, droplet: droplet_docker) }
    let!(:unstaged_app_docker) { VCAP::CloudController::AppModel.make(:docker, droplet: nil) }
    let!(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'some-type') }
    let!(:unstaged_process) { VCAP::CloudController::ProcessModel.make(app: unstaged_app_docker, type: 'test') }
    let!(:route) { VCAP::CloudController::Route.make(space: app.space) }
    let!(:process_docker) { VCAP::CloudController::ProcessModel.make(app: app_docker, type: 'some-type') }
    let!(:route_docker) { VCAP::CloudController::Route.make(space: app_docker.space) }
    let!(:droplet_docker) do
      VCAP::CloudController::DropletModel.make(
        :docker,
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}]}'
      )
    end

    let!(:route_mapping) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app,
        app_port: 1234,
        route: route,
        process_type: process.type,
        weight: 55
      )
    end

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      context 'destination for buildpack app with specified port' do
        it 'presents the destinations as json' do
          expect(result[:destinations]).to have(1).item
          expect(result[:links]).to include(:self)
          expect(result[:links]).to include(:route)
        end

        it 'should present destinations correctly' do
          expect(result[:destinations][0][:guid]).to eq(route_mapping.guid)
          expect(result[:destinations][0][:app]).to match({
            guid: app.guid,
            process: { type: process.type }
          })
          expect(result[:destinations][0][:port]).to eq(route_mapping.app_port)
          expect(result[:destinations][0][:weight]).to eq(route_mapping.weight)
        end

        context 'links' do
          it 'includes correct link hrefs' do
            expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}/destinations")
            expect(result[:links][:route][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}")
          end
        end
      end

      context 'destination for buildpack app with default port specified' do
        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app,
            route: route,
            app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT,
            process_type: process.type,
            weight: 55
          )
        end
        it 'presents the destinations as json' do
          expect(result[:destinations]).to have(1).item
          expect(result[:links]).to include(:self)
          expect(result[:links]).to include(:route)
        end

        it 'should present destinations correctly' do
          expect(result[:destinations][0][:guid]).to eq(route_mapping.guid)
          expect(result[:destinations][0][:app]).to match({
            guid: app.guid,
            process: { type: process.type }
          })
          expect(result[:destinations][0][:port]).to eq(route_mapping.app_port)
          expect(result[:destinations][0][:weight]).to eq(route_mapping.weight)
        end

        context 'links' do
          it 'includes correct link hrefs' do
            expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}/destinations")
            expect(result[:links][:route][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}")
          end
        end
      end

      context 'destination for staged docker app' do
        subject(:presenter) { RouteDestinationsPresenter.new(route_docker) }

        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app_docker,
            route: route_docker,
            app_port: VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED,
            process_type: process.type,
            weight: 55
          )
        end

        it 'presents the destinations as json' do
          expect(result[:destinations]).to have(1).item
          expect(result[:links]).to include(:self)
          expect(result[:links]).to include(:route)
        end

        it 'should present destinations correctly' do
          expect(result[:destinations][0][:guid]).to eq(route_mapping.guid)
          expect(result[:destinations][0][:app]).to match({
            guid: app_docker.guid,
            process: { type: process.type }
          })
          expect(result[:destinations][0][:port]).to eq(1024)
          expect(result[:destinations][0][:weight]).to eq(route_mapping.weight)
        end

        context 'links' do
          it 'includes correct link hrefs' do
            expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}/destinations")
            expect(result[:links][:route][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}")
          end
        end
      end

      context 'destination for unstaged docker app' do
        subject(:presenter) { RouteDestinationsPresenter.new(route_docker) }

        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: unstaged_app_docker,
            route: route_docker,
            app_port: VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED,
            process_type: unstaged_process.type,
            weight: 55
          )
        end

        it 'presents the destinations as json' do
          expect(result[:destinations]).to have(1).item
          expect(result[:links]).to include(:self)
          expect(result[:links]).to include(:route)
        end

        it 'should present destinations correctly' do
          expect(result[:destinations][0][:guid]).to eq(route_mapping.guid)
          expect(result[:destinations][0][:app]).to match({
            guid: unstaged_app_docker.guid,
            process: { type: unstaged_process.type }
          })
          expect(result[:destinations][0][:port]).to eq(8080)
          expect(result[:destinations][0][:weight]).to eq(route_mapping.weight)
        end

        context 'links' do
          it 'includes correct link hrefs' do
            expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}/destinations")
            expect(result[:links][:route][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}")
          end
        end
      end

      context 'destination for unstaged docker app without process' do
        subject(:presenter) { RouteDestinationsPresenter.new(route_docker) }

        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app_docker_without_process,
            route: route_docker,
            app_port: VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED,
            process_type: 'web',
            weight: 55
          )
        end

        it 'presents the destinations as json' do
          expect(result[:destinations]).to have(1).item
          expect(result[:links]).to include(:self)
          expect(result[:links]).to include(:route)
        end

        it 'should present destinations correctly' do
          expect(result[:destinations][0][:guid]).to eq(route_mapping.guid)
          expect(result[:destinations][0][:app]).to match({
            guid: app_docker_without_process.guid,
            process: { type: 'web' }
          })
          expect(result[:destinations][0][:port]).to eq(1024)
          expect(result[:destinations][0][:weight]).to eq(route_mapping.weight)
        end

        context 'links' do
          it 'includes correct link hrefs' do
            expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}/destinations")
            expect(result[:links][:route][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}")
          end
        end
      end
    end
  end
end
