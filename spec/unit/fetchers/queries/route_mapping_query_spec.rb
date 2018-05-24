require 'spec_helper'
require 'fetchers/queries/route_mapping_query'

module VCAP::RestAPI
  RSpec.describe RouteMappingQuery do
    let(:queryable_attributes) { %w(app_guid) }

    describe 'filtering by app_guid' do
      context 'equals operation (:)' do
        it 'works with a single app guid' do
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

        it 'works when no app guid is provided' do
          results = AppQuery.filtered_dataset_from_query_params(
            VCAP::CloudController::RouteMappingModel,
            VCAP::CloudController::RouteMappingModel.dataset,
            queryable_attributes,
            { q: ['app_guid:'] }
          ).all

          expect(results).to eq([])
        end
      end

      context 'IN operation' do
        it 'works for IN with a single app guid' do
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

        it 'works for IN with multiple app guids' do
          app_guid1 = 'some_app_guid1'
          app_model1 = VCAP::CloudController::AppModel.make(guid: app_guid1)
          route_mapping_1 = VCAP::CloudController::RouteMappingModel.make(app: app_model1, app_port: 1)
          route_mapping_2 = VCAP::CloudController::RouteMappingModel.make(app: app_model1, app_port: 2)

          app_guid2 = 'some_app_guid2'
          app_model2 = VCAP::CloudController::AppModel.make(guid: app_guid2)
          route_mapping_3 = VCAP::CloudController::RouteMappingModel.make(app: app_model2, app_port: 3)

          VCAP::CloudController::RouteMappingModel.make(app_guid: 'different_app_guid')

          results = RouteMappingQuery.filtered_dataset_from_query_params(
            VCAP::CloudController::RouteMappingModel,
            VCAP::CloudController::RouteMappingModel.dataset,
            queryable_attributes,
            { q: ["app_guid IN #{app_guid1},#{app_guid2}"] }
          ).all

          expect(results).to match_array([route_mapping_1, route_mapping_2, route_mapping_3])
        end

        it 'works for IN with no app guids' do
          results = RouteMappingQuery.filtered_dataset_from_query_params(
            VCAP::CloudController::RouteMappingModel,
            VCAP::CloudController::RouteMappingModel.dataset,
            queryable_attributes,
            { q: ['app_guid IN '] }
          ).all

          expect(results).to eq([])
        end
      end
    end
  end
end
