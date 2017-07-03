require 'spec_helper'
require 'presenters/v3/route_mapping_presenter'
require 'messages/route_mappings/route_mappings_list_message'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RouteMappingPresenter do
    subject(:presenter) { described_class.new(route_mapping) }

    let(:route_mapping) do
      VCAP::CloudController::RouteMappingModel.make(
        app:          app,
        app_port:     1234,
        route:        route,
        process_type: process.type,
      )
    end
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'some-type') }
    let(:route) { VCAP::CloudController::Route.make(space: app.space) }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the route_mapping as json' do
        expect(result[:guid]).to eq(route_mapping.guid)
        expect(result[:created_at]).to eq(route_mapping.created_at)
        expect(result[:updated_at]).to eq(route_mapping.updated_at)
        expect(result[:links]).to include(:self)
        expect(result[:links]).to include(:app)
        expect(result[:links]).to include(:route)
        expect(result[:links]).to include(:process)
      end

      context 'links' do
        it 'includes correct link hrefs' do
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/route_mappings/#{route_mapping.guid}")
          expect(result[:links][:app][:href]).to eq("#{link_prefix}/v3/apps/#{app.guid}")
          expect(result[:links][:route][:href]).to eq("#{link_prefix}/v2/routes/#{route_mapping.route.guid}")
          expect(result[:links][:process][:href]).to eq("#{link_prefix}/v3/apps/#{app.guid}/processes/some-type")
        end

        context 'when the process is gone' do
          let(:route_mapping) do
            VCAP::CloudController::RouteMappingModel.make(process_type: nil)
          end

          it 'has a null link for process' do
            expect(result[:links][:process]).to be_nil
          end
        end
      end
    end
  end
end
