require 'spec_helper'
require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  RSpec.describe SequelPaginator do
    let(:paginator) { SequelPaginator.new }

    describe '#get_page' do
      let(:dataset) { AppModel.dataset }
      let!(:app_model1) { AppModel.make }
      let!(:app_model2) { AppModel.make }
      let(:page) { 1 }
      let(:per_page) { 1 }

      it 'finds all records from the page upto the per_page limit' do
        options = { page: page, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        paginated_result = paginator.get_page(dataset, pagination_options)
        expect(paginated_result.records.length).to eq(1)
      end

      it 'pages properly' do
        options = { page: 1, per_page: per_page }
        pagination_options     = PaginationOptions.new(options)
        first_paginated_result = paginator.get_page(dataset, pagination_options)

        options = { page: 2, per_page: per_page }
        pagination_options      = PaginationOptions.new(options)
        second_paginated_result = paginator.get_page(dataset, pagination_options)

        expect(first_paginated_result.records.first.guid).to eq(app_model1.guid)
        expect(second_paginated_result.records.first.guid).to eq(app_model2.guid)
      end

      it 'sorts by the order_by option in the corresponding order_direction' do
        options = { page: 1, per_page: 2, order_by: 'name', order_direction: 'asc' }
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
        options = { page: 1, per_page: per_page }
        pagination_options = PaginationOptions.new(options)
        new_dataset = dataset.join(PackageModel.table_name, "#{PackageModel.table_name}__app_guid".to_sym => "#{AppModel.table_name}__guid".to_sym)

        paginated_result = nil
        expect {
          paginated_result = paginator.get_page(new_dataset, pagination_options)
        }.not_to raise_error

        expect(paginated_result.total).to be > 0
      end
    end
  end
end
