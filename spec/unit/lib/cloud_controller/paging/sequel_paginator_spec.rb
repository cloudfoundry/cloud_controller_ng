require 'spec_helper'
require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  RSpec.describe SequelPaginator do
    let(:paginator) { SequelPaginator.new }

    describe '#get_page' do
      let(:dataset) { AppModel.dataset }
      let!(:space) { Space.make }
      let!(:app_model1) { AppModel.make(space: space) }
      let!(:app_model2) { AppModel.make }
      let(:page) { 1 }
      let(:per_page) { 1 }

      it 'finds all records from the page upto the per_page limit' do
        options = { page: page, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.length).to eq(1)
      end

      it 'returns no rows when result set is empty' do
        options = { page: page, per_page: per_page }
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
        options = { page: page, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        new_dataset = dataset.join(PackageModel.table_name, "#{PackageModel.table_name}__app_guid".to_sym => "#{AppModel.table_name}__guid".to_sym)

        paginated_result = nil
        expect {
          paginated_result = paginator.get_page(new_dataset, pagination_options)
        }.not_to raise_error

        expect(paginated_result.total).to be > 0
      end

      it 'works with eager' do
        options = { page: page, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        eager_dataset = AppModel.dataset.eager(:space)
        paginated_result = nil
        expect {
          paginated_result = paginator.get_page(eager_dataset, pagination_options)
        }.to have_queried_db_times(/select/i, paginator.can_paginate_with_window_function?(dataset) ? 2 : 3)
        expect(paginated_result.total).to eq(2)
        expect(paginated_result.records[0].associations[:space].name).to eq(space.name)
      end

      it 'works with eager_graph' do
        options = { page: page, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        eager_graph_dataset = AppModel.dataset.eager_graph(:space)
        paginated_result = nil
        expect {
          paginated_result = paginator.get_page(eager_graph_dataset, pagination_options)
        }.to have_queried_db_times(/select/i, paginator.can_paginate_with_window_function?(dataset) ? 1 : 2)
        expect(paginated_result.total).to eq(2)
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
        options = { page: page, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        orphaned_blob_dataset = OrphanedBlob.dataset
        OrphanedBlob.make.save
        paginated_result = nil
        expect {
          paginated_result = paginator.get_page(orphaned_blob_dataset, pagination_options)
        }.not_to raise_error
        expect(paginated_result.total).to be 1
      end

      it 'only calls DB once if DB supports pagination with window function' do
        skip 'DB does not support pagination with window function' unless paginator.can_paginate_with_window_function?(dataset)
        options = { page: page, per_page: per_page }
        pagination_options = PaginationOptions.new(options)

        paginated_result = nil
        expect {
          paginated_result = paginator.get_page(dataset, pagination_options)
        }.to have_queried_db_times(/select/i, 1)
        expect(paginated_result.total).to be > 1
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
