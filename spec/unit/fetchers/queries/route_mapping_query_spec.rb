require 'spec_helper'
require 'fetchers/queries/route_mapping_query'

module VCAP::RestAPI
  RSpec.describe RouteMappingQuery do
    let(:queryable_attributes) { %w(app_guid) }

    describe 'filtering by app_guid' do
      it 'works for equals' do
        app_guid = 'some_app_guid'
        app_model = VCAP::CloudController::AppModel.make(guid: app_guid)

        route_mapping = VCAP::CloudController::RouteMappingModel.make(app: app_model, app_port: 1)

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::RouteMappingModel,
          VCAP::CloudController::RouteMappingModel.dataset,
          queryable_attributes,
          { q: ["app_guid:#{route_mapping.app_guid}"] }
        ).all

        expect(results).to match_array([route_mapping])
      end

      it 'works for IN' do
        app_guid = 'some_app_guid'
        app_model = VCAP::CloudController::AppModel.make(guid: app_guid)

        route_mapping_1 = VCAP::CloudController::RouteMappingModel.make(app: app_model, app_port: 1)
        route_mapping_2 = VCAP::CloudController::RouteMappingModel.make(app: app_model, app_port: 2)
        VCAP::CloudController::RouteMappingModel.make(app_guid: 'different_app_guid')

        results = RouteMappingQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::RouteMappingModel,
          VCAP::CloudController::RouteMappingModel.dataset,
          queryable_attributes,
          { q: ["app_guid IN #{app_guid}"] }
        ).all

        expect(results).to match_array([route_mapping_1, route_mapping_2])
      end
    end
  end
end
