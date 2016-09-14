require 'spec_helper'
require 'queries/v2/app_query'

module VCAP::RestAPI
  RSpec.describe AppQuery do
    let(:queryable_attributes) { %w(organization_guid stack_guid name) }

    describe 'filtering by organization_guid' do
      it 'works for equals' do
        expected_app = VCAP::CloudController::App.make
        VCAP::CloudController::App.make

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::App,
          VCAP::CloudController::App.dataset,
          queryable_attributes,
          { q: ["organization_guid:#{expected_app.organization.guid}"] }
        ).all

        expect(results).to match_array([expected_app])
      end

      it 'works for IN' do
        expected_app1 = VCAP::CloudController::App.make
        expected_app2 = VCAP::CloudController::App.make
        VCAP::CloudController::App.make

        org_guids = [expected_app1.organization.guid, expected_app2.organization.guid].join(',')

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::App,
          VCAP::CloudController::App.dataset,
          queryable_attributes,
          { q: ["organization_guid IN #{org_guids}"] }
        ).all

        expect(results).to match_array([expected_app1, expected_app2])
      end
    end

    describe 'filtering by stack_guid' do
      it 'works for equals' do
        expected_app = VCAP::CloudController::App.make
        VCAP::CloudController::App.make

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::App,
          VCAP::CloudController::App.dataset,
          queryable_attributes,
          { q: ["stack_guid:#{VCAP::CloudController::Stack.find(name: expected_app.app.lifecycle_data.stack).guid}"] }
        ).all

        expect(results).to match_array([expected_app])
      end

      it 'works for IN' do
        expected_app1 = VCAP::CloudController::App.make
        expected_app2 = VCAP::CloudController::App.make
        VCAP::CloudController::App.make

        stack_guids = [
          VCAP::CloudController::Stack.find(name: expected_app1.app.lifecycle_data.stack).guid,
          VCAP::CloudController::Stack.find(name: expected_app2.app.lifecycle_data.stack).guid
        ].join(',')

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::App,
          VCAP::CloudController::App.dataset,
          queryable_attributes,
          { q: ["stack_guid IN #{stack_guids}"] }
        ).all

        expect(results).to match_array([expected_app1, expected_app2])
      end
    end

    describe 'filtering by name' do
      it 'works for equals' do
        expected_app = VCAP::CloudController::App.make
        expected_app.app.update(name: 'expected-name')
        VCAP::CloudController::App.make

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::App,
          VCAP::CloudController::App.dataset,
          queryable_attributes,
          { q: ['name:expected-name'] }
        ).all

        expect(results).to match_array([expected_app])
      end

      it 'works for IN' do
        expected_app1 = VCAP::CloudController::App.make
        expected_app1.app.update(name: 'expected-name1')
        expected_app2 = VCAP::CloudController::App.make
        expected_app2.app.update(name: 'expected-name2')
        VCAP::CloudController::App.make

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::App,
          VCAP::CloudController::App.dataset,
          queryable_attributes,
          { q: ['name IN expected-name1,expected-name2'] }
        ).all

        expect(results).to match_array([expected_app1, expected_app2])
      end
    end
  end
end
