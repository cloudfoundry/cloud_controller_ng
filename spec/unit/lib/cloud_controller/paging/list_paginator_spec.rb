require 'spec_helper'
require 'cloud_controller/paging/list_paginator'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  RSpec.describe ListPaginator do
    let(:paginator) { ListPaginator.new }

    describe '#get_page' do
      let(:list) { [app_model1, app_model2] }
      let(:default_options) { { order_by: 'id', order_direction: 'asc', page: 1, per_page: per_page } }
      let!(:app_model1) { AppModel.make(name: 'zora') }
      let!(:app_model2) { AppModel.make(name: 'dora') }
      let(:per_page) { 1 }

      it 'finds all records from the page upto the per_page limit' do
        pagination_options = PaginationOptions.new(default_options)

        paginated_result = paginator.get_page(list, pagination_options)

        expect(paginated_result.records.length).to eq(1)
        expect(paginated_result.records.first).to eq(app_model1)
        expect(paginated_result.total).to eq(2)
      end

      it 'pages properly' do
        pagination_options     = PaginationOptions.new(default_options)
        first_paginated_result = paginator.get_page(list, pagination_options)

        pagination_options      = PaginationOptions.new(default_options.merge(page: 2))
        second_paginated_result = paginator.get_page(list, pagination_options)

        expect(first_paginated_result.records.first.guid).to eq(app_model1.guid)
        expect(second_paginated_result.records.first.guid).to eq(app_model2.guid)
      end

      it 'returns an empty set when you go off the end' do
        pagination_options = PaginationOptions.new(default_options.merge(page: 100))
        result = paginator.get_page(list, pagination_options).records
        expect(result).to eq([])
      end

      describe 'sorting' do
        let(:per_page) { 10 }
        it 'sorts by the order_by option in the corresponding order_direction for asc' do
          app_model1.update(name: 'b')
          app_model2.update(name: 'a')
          pagination_options = PaginationOptions.new(default_options.merge(order_by: 'name'))
          paginated_result = paginator.get_page(list, pagination_options)
          expect(paginated_result.records.first.guid).to eq(app_model2.guid)
        end

        it 'sorts by the order_by option in the corresponding order_direction for desc' do
          app_model1.update(name: 'b')
          app_model2.update(name: 'a')
          pagination_options = PaginationOptions.new(default_options.merge(order_by: 'name', order_direction: 'desc'))
          paginated_result = paginator.get_page(list, pagination_options)
          expect(paginated_result.records.first.guid).to eq(app_model1.guid)
        end

        it 'handles nil values' do
          app_model1.name = 'a'
          app_model2.name = nil
          pagination_options = PaginationOptions.new(default_options.merge(order_by: 'name', order_direction: 'asc'))
          paginated_result = paginator.get_page(list, pagination_options)
          expect(paginated_result.records).to eq([app_model2, app_model1])
        end
      end
    end
  end
end
