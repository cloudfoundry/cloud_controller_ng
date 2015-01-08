require 'spec_helper'
require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  describe SequelPaginator do
    let(:paginator) { SequelPaginator.new }

    describe '#get_page' do
      let(:dataset) { AppModel.dataset }
      let!(:app_model1) { AppModel.make }
      let!(:app_model2) { AppModel.make }
      let(:page) { 1 }
      let(:per_page) { 1 }

      it 'defaults to the first page if page is nil' do
        pagination_options = PaginationOptions.new(nil, per_page)

        paginated_result = paginator.get_page(dataset, pagination_options)

        expect(paginated_result.pagination_options.page).to eq(1)
      end

      it 'defaults to the first page if page is 0' do
        pagination_options = PaginationOptions.new(0, per_page)

        paginated_result = paginator.get_page(dataset, pagination_options)

        expect(paginated_result.pagination_options.page).to eq(1)
      end

      it 'defaults to listing 50 records per page if per_page is nil' do
        pagination_options = PaginationOptions.new(page, nil)

        paginated_result = paginator.get_page(dataset, pagination_options)

        expect(paginated_result.pagination_options.per_page).to eq(50)
      end

      it 'defaults to listing 50 records per page if per_page is 0' do
        pagination_options = PaginationOptions.new(page, 0)

        paginated_result = paginator.get_page(dataset, pagination_options)

        expect(paginated_result.pagination_options.per_page).to eq(50)
      end

      it 'limits the listing to 5000 records per page' do
        pagination_options = PaginationOptions.new(page, 5001)

        paginated_result = paginator.get_page(dataset, pagination_options)

        expect(paginated_result.pagination_options.per_page).to eq(5000)
      end

      it 'finds all records from the page upto the per_page limit' do
        per_page           = 1
        pagination_options = PaginationOptions.new(page, per_page)

        paginated_result = paginator.get_page(dataset, pagination_options)

        expect(paginated_result.records.length).to eq(1)
      end

      it 'pages properly' do
        pagination_options     = PaginationOptions.new(1, per_page)
        first_paginated_result = paginator.get_page(dataset, pagination_options)

        pagination_options      = PaginationOptions.new(2, per_page)
        second_paginated_result = paginator.get_page(dataset, pagination_options)

        expect(first_paginated_result.records.first.guid).to eq(app_model1.guid)
        expect(second_paginated_result.records.first.guid).to eq(app_model2.guid)
      end
    end
  end
end
