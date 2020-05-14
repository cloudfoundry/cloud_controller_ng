require 'spec_helper'
require 'presenters/v3/route_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RoutePresenter do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:route_host) { 'host' }
    let(:path) { '/path' }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

    describe '#to_hash' do
      subject do
        RoutePresenter.new(route).to_hash
      end

      let(:route) do
        VCAP::CloudController::Route.make(
          host: route_host,
          path: path,
          space: space,
          domain: domain
        )
      end

      let!(:destination) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app,
          app_port: 1234,
          route: route,
          process_type: 'web',
          weight: 55
        )
      end

      let!(:destination2) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app,
          app_port: 5678,
          route: route,
          process_type: 'other-process',
          weight: 45
        )
      end

      let!(:route_label) do
        VCAP::CloudController::RouteLabelModel.make(
          resource_guid: route.guid,
          key_prefix: 'pfx.com',
          key_name: 'potato',
          value: 'baked'
        )
      end

      let!(:route_annotation) do
        VCAP::CloudController::RouteAnnotationModel.make(
          resource_guid: route.guid,
          key: 'contacts',
          value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)'
        )
      end

      it 'presents the route as json' do
        expect(subject[:guid]).to eq(route.guid)
        expect(subject[:protocol]).to eq('http')
        expect(subject[:created_at]).to be_a(Time)
        expect(subject[:updated_at]).to be_a(Time)
        expect(subject[:host]).to eq(route_host)
        expect(subject[:path]).to eq(path)
        expect(subject[:url]).to eq("#{route.host}.#{domain.name}#{route.path}")

        expected_destinations = [
          {
            guid: destination.guid,
            app: {
              guid: destination.app_guid,
              process: {
                type: destination.process_type
              }
            },
            weight: destination.weight,
            port: destination.presented_port
          },
          {
            guid: destination2.guid,
            app: {
              guid: destination2.app_guid,
              process: {
                type: destination2.process_type
              }
            },
            weight: destination2.weight,
            port: destination2.presented_port
          }
        ]
        expect(subject[:destinations]).to match_array(expected_destinations)

        expect(subject[:metadata][:labels]).to eq({ 'pfx.com/potato' => 'baked' })
        expect(subject[:metadata][:annotations]).to eq({ 'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)' })
        expect(subject[:relationships][:space][:data]).to eq({ guid: space.guid })
        expect(subject[:relationships][:domain][:data]).to eq({ guid: domain.guid })
        expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route.guid}")
        expect(subject[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{space.guid}")
        expect(subject[:links][:domain][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}")
        expect(subject[:links][:destinations][:href]).to eq("#{link_prefix}/v3/routes/#{route.guid}/destinations")
      end

      context 'when the host is empty' do
        let(:route) do
          VCAP::CloudController::Route.make(
            host: '',
            path: path,
            space: space,
            domain: domain
          )
        end

        it 'formats the url correctly' do
          expect(subject[:url]).to eq("#{domain.name}#{route.path}")
        end
      end

      context 'when there are decorators' do
        let(:banana_decorator) do
          Class.new do
            class << self
              def decorate(hash, routes)
                hash[:included] ||= {}
                hash[:included][:bananas] = routes.map { |route| "#{route.host} is bananas" }
                hash
              end
            end
          end
        end

        subject { RoutePresenter.new(route, decorators: [banana_decorator]).to_hash }

        it 'runs the decorators' do
          expect(subject[:included][:bananas]).to match_array(['host is bananas'])
        end
      end
    end
  end
end
