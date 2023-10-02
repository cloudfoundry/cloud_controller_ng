require 'spec_helper'
require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  RSpec.describe SequelPaginator do
    let(:paginator) { SequelPaginator.new }

    describe '#get_page' do
      let(:dataset) { AppModel.dataset }
      let!(:space) { Space.make }
      let!(:app_model1) { AppModel.make(space:) }
      let!(:app_model2) { AppModel.make }
      let!(:app_model3) { AppModel.make }
      let!(:app_model4) { AppModel.make }
      let(:page) { 1 }
      let(:per_page) { 1 }

      it 'finds all records from the page upto the per_page limit' do
        options = { page:, per_page: }
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.length).to eq(1)
      end

      it 'returns no rows when result set is empty' do
        options = { page:, per_page: }
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(ServiceKey.dataset, pagination_options)
        expect(paginated_result.records.length).to eq(0)
        expect(paginated_result.total).to eq(0)
      end

      it 'pages properly' do
        options = { page: 1, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        first_paginated_result = paginator.get_page(dataset, pagination_options)

        options = { page: 2, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        second_paginated_result = paginator.get_page(dataset, pagination_options)

        expect(first_paginated_result.records.first.guid).to eq(app_model1.guid)
        expect(second_paginated_result.records.first.guid).to eq(app_model2.guid)
      end

      it 'sorts by the order_by option in the corresponding order_direction' do
        options = { page: page, per_page: 2, order_by: 'name', order_direction: 'asc' }
        app_model2.update(name: 'a')
        app_model1.update(name: 'b')
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.first.guid).to eq(app_model2.guid)

        app_model2.update(name: 'c')
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.first.guid).to eq(app_model1.guid)
      end

      it 'works with a multi table result set' do
        PackageModel.make(app: app_model1)
        options = { page:, per_page: }
        pagination_options = PaginationOptions.new(options)
        new_dataset = dataset.join(PackageModel.table_name, "#{PackageModel.table_name}__app_guid".to_sym => "#{AppModel.table_name}__guid".to_sym)

        paginated_result = nil
        expect do
          paginated_result = paginator.get_page(new_dataset, pagination_options)
        end.not_to raise_error

        expect(paginated_result.total).to be > 0
      end

      it 'works with eager' do
        options = { page:, per_page: }
        pagination_options = PaginationOptions.new(options)
        eager_dataset = AppModel.dataset.eager(:space)
        paginated_result = nil
        expect do
          paginated_result = paginator.get_page(eager_dataset, pagination_options)
        end.to have_queried_db_times(/select/i, paginator.can_paginate_with_window_function?(dataset) ? 2 : 3)
        expect(paginated_result.total).to eq(4)
        expect(paginated_result.records[0].associations[:space].name).to eq(space.name)
      end

      it 'works with eager_graph' do
        options = { page:, per_page: }
        pagination_options = PaginationOptions.new(options)
        eager_graph_dataset = AppModel.dataset.eager_graph(:space)
        paginated_result = nil
        expect do
          paginated_result = paginator.get_page(eager_graph_dataset, pagination_options)
        end.to have_queried_db_times(/select/i, paginator.can_paginate_with_window_function?(dataset) ? 1 : 2)
        expect(paginated_result.total).to eq(4)
        expect(paginated_result.records[0].associations[:space].name).to eq(space.name)
      end

      it 'orders by GUID as a secondary field when available' do
        options = { page: page, per_page: 2, order_by: 'created_at', order_direction: 'asc' }
        app_model1.update(guid: '1', created_at: '2019-12-25T13:00:00Z')
        app_model2.update(guid: '2', created_at: '2019-12-25T13:00:00Z')

        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.first.guid).to eq(app_model1.guid)
        expect(paginated_result.records.second.guid).to eq(app_model2.guid)
      end

      it 'does not order by GUID when the table has no GUID' do
        options = { page:, per_page: }
        pagination_options = PaginationOptions.new(options)
        orphaned_blob_dataset = OrphanedBlob.dataset
        OrphanedBlob.make.save
        paginated_result = nil
        expect do
          paginated_result = paginator.get_page(orphaned_blob_dataset, pagination_options)
        end.not_to raise_error
        expect(paginated_result.total).to be 1
      end

      it 'does not order by GUID when the primary order is by ID' do
        options = { page: page, per_page: 2, order_by: 'id', order_direction: 'asc' }

        pagination_options = PaginationOptions.new(options)
        expect do
          paginator.get_page(dataset, pagination_options)
        end.to have_queried_db_times(/ORDER BY .\w*.\..id. ASC LIMIT/i, 1)
        expect do
          paginator.get_page(dataset, pagination_options)
        end.to have_queried_db_times(/ORDER BY .\w*.\..id. ASC, .\w*.\..guid. ASC LIMIT/i, 0)
      end

      it 'produces a descending order which is exactly the reverse order of the ascending ordering' do
        app_model1.update(guid: '1', created_at: '2019-12-25T13:00:00Z')
        app_model2.update(guid: '2', created_at: '2019-12-25T13:00:01Z')
        app_model3.update(guid: '3', created_at: '2019-12-25T13:00:01Z')
        app_model4.update(guid: '4', created_at: '2019-12-25T13:00:02Z')

        options = { page: page, per_page: 4, order_by: 'created_at', order_direction: 'desc' }
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.first.guid).to eq(app_model4.guid)
        expect(paginated_result.records.second.guid).to eq(app_model3.guid)
        expect(paginated_result.records.third.guid).to eq(app_model2.guid)
        expect(paginated_result.records.fourth.guid).to eq(app_model1.guid)

        options = { page: page, per_page: 4, order_by: 'created_at', order_direction: 'asc' }
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.first.guid).to eq(app_model1.guid)
        expect(paginated_result.records.second.guid).to eq(app_model2.guid)
        expect(paginated_result.records.third.guid).to eq(app_model3.guid)
        expect(paginated_result.records.fourth.guid).to eq(app_model4.guid)
      end

      it 'only calls DB once if DB supports pagination with window function' do
        skip 'DB does not support pagination with window function' unless paginator.can_paginate_with_window_function?(dataset)
        options = { page:, per_page: }
        pagination_options = PaginationOptions.new(options)

        paginated_result = nil
        expect do
          paginated_result = paginator.get_page(dataset, pagination_options)
        end.to have_queried_db_times(/select/i, 1)
        expect(paginated_result.total).to be > 1
      end

      context 'events table' do
        let(:dataset) { Event.dataset }
        let!(:event_1) { Event.make(guid: '1', created_at: '2022-12-20T10:47:01Z') }
        let!(:event_2) { Event.make(guid: '2', created_at: '2022-12-20T10:47:02Z') }
        let!(:event_3) { Event.make(guid: '3', created_at: '2022-12-20T10:47:03Z') }
        let!(:event_4) { Event.make(guid: '4', created_at: '2022-12-20T10:47:04Z') }

        it 'does not use window function' do
          options = { page:, per_page: }
          pagination_options = PaginationOptions.new(options)

          paginated_result = nil
          expect do
            paginated_result = paginator.get_page(dataset, pagination_options)
          end.to have_queried_db_times(/select/i, 2)
          expect(paginated_result.total).to be > 1
        end
      end

      context 'AppUsageEvents table' do
        before do
          AppUsageEvent.make(guid: '1', created_at: '2022-12-20T10:47:01Z')
          AppUsageEvent.make(guid: '2', created_at: '2022-12-20T10:47:02Z')
          AppUsageEvent.make(guid: '3', created_at: '2022-12-20T10:47:03Z')
          AppUsageEvent.make(guid: '4', created_at: '2022-12-20T10:47:04Z')
        end

        it 'does not use window function' do
          options = { page:, per_page: }
          pagination_options = PaginationOptions.new(options)

          paginated_result = nil
          expect do
            paginated_result = paginator.get_page(AppUsageEvent.dataset, pagination_options)
          end.to have_queried_db_times(/over/i, 0)
          expect(paginated_result.total).to be > 1
        end
      end

      it 'returns correct total results for distinct result' do
        options = { page: page, per_page: per_page, order_by: :key_name }
        pagination_options = PaginationOptions.new(options)
        2.times { SpaceLabelModel.create(key_name: 'testLabel') }
        dataset = SpaceLabelModel.dataset.distinct(:key_name)
        paginated_result = paginator.get_page(dataset, pagination_options)

        expect(paginated_result.total).to eq(1)
      end
    end
  end
end
