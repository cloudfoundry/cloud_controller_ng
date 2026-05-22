require 'spec_helper'
require 'fetchers/queries/app_query'

module VCAP::RestAPI
  RSpec.describe AppQuery do
    let(:queryable_attributes) { %w[organization_guid stack_guid name] }

    describe 'filtering by organization_guid' do
      it 'works for equals' do
        expected_process = create(:process_model).reload
        create(:process_model)

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::ProcessModel,
          VCAP::CloudController::ProcessModel.dataset,
          queryable_attributes,
          { q: ["organization_guid:#{expected_process.organization.guid}"] }
        ).all

        expect(results).to contain_exactly(expected_process)
      end

      it 'works for IN' do
        expected_process1 = create(:process_model).reload
        expected_process2 = create(:process_model).reload
        create(:process_model)

        org_guids = [expected_process1.organization.guid, expected_process2.organization.guid].join(',')

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::ProcessModel,
          VCAP::CloudController::ProcessModel.dataset,
          queryable_attributes,
          { q: ["organization_guid IN #{org_guids}"] }
        ).all

        expect(results).to contain_exactly(expected_process1, expected_process2)
      end
    end

    describe 'filtering by stack_guid' do
      it 'works for equals' do
        expected_process = create(:process_model)
        create(:process_model)

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::ProcessModel,
          VCAP::CloudController::ProcessModel.dataset,
          queryable_attributes,
          { q: ["stack_guid:#{VCAP::CloudController::Stack.find(name: expected_process.app.lifecycle_data.stack).guid}"] }
        ).all

        expect(results).to contain_exactly(expected_process)
      end

      it 'works for IN' do
        expected_process1 = create(:process_model)
        expected_process2 = create(:process_model)
        create(:process_model)

        stack_guids = [
          VCAP::CloudController::Stack.find(name: expected_process1.app.lifecycle_data.stack).guid,
          VCAP::CloudController::Stack.find(name: expected_process2.app.lifecycle_data.stack).guid
        ].join(',')

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::ProcessModel,
          VCAP::CloudController::ProcessModel.dataset,
          queryable_attributes,
          { q: ["stack_guid IN #{stack_guids}"] }
        ).all

        expect(results).to contain_exactly(expected_process1, expected_process2)
      end
    end

    describe 'filtering by name' do
      it 'works for equals' do
        expected_process = create(:process_model)
        expected_process.app.update(name: 'expected-name')
        create(:process_model)

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::ProcessModel,
          VCAP::CloudController::ProcessModel.dataset,
          queryable_attributes,
          { q: ['name:expected-name'] }
        ).all

        expect(results).to contain_exactly(expected_process)
      end

      it 'works for IN' do
        expected_process1 = create(:process_model)
        expected_process1.app.update(name: 'expected-name1')
        expected_process2 = create(:process_model)
        expected_process2.app.update(name: 'expected-name2')
        create(:process_model)

        results = AppQuery.filtered_dataset_from_query_params(
          VCAP::CloudController::ProcessModel,
          VCAP::CloudController::ProcessModel.dataset,
          queryable_attributes,
          { q: ['name IN expected-name1,expected-name2'] }
        ).all

        expect(results).to contain_exactly(expected_process1, expected_process2)
      end
    end
  end
end
