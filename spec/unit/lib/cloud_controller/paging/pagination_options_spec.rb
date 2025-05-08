require 'spec_helper'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  RSpec.describe PaginationOptions do
    describe '.from_params' do
      let(:params) do
        {
          page: 4,
          per_page: 56,
          order_by: '+updated_at',
          extra: 'stuff'
        }
      end

      it 'returns the correct PaginationOptions' do
        result = PaginationOptions.from_params(params)

        expect(result.page).to eq(4)
        expect(result.per_page).to eq(56)
        expect(result.order_by).to eq('updated_at')
        expect(result.order_direction).to eq('asc')
      end

      describe 'order direction' do
        it 'ascending if order by is prepended with "+"' do
          result = PaginationOptions.from_params(params)

          expect(result.order_by).to eq('updated_at')
          expect(result.order_direction).to eq('asc')
        end

        it 'descending if order by is prepended with "-"' do
          params[:order_by] = '-updated_at'
          result = PaginationOptions.from_params(params)

          expect(result.order_by).to eq('updated_at')
          expect(result.order_direction).to eq('desc')
        end

        it 'defaults to ascending' do
          params[:order_by] = 'updated_at'
          result = PaginationOptions.from_params(params)

          expect(result.order_by).to eq('updated_at')
          expect(result.order_direction).to eq('asc')
        end
      end
    end

    describe 'default values' do
      let(:pagination_options) { PaginationOptions.new(options) }
      let(:options) { { page:, per_page:, order_by:, order_direction: } }
      let(:page) { 2 }
      let(:per_page) { 5 }
      let(:order_by) { 'anything' }
      let(:order_direction) { 'desc' }

      context 'page' do
        context 'when page is nil' do
          let(:page) { nil }

          it 'defaults to the first page if page is nil' do
            expect(pagination_options.page).to eq(1)
          end
        end
      end

      context 'per_page' do
        context 'when per_page is nil' do
          let(:per_page) { nil }

          it 'defaults to 50' do
            expect(pagination_options.per_page).to eq(50)
          end
        end
      end

      context 'order_by' do
        context 'when the order_by is nil' do
          let(:order_by) { nil }

          it 'defaults to id' do
            expect(pagination_options.order_by).to eq('id')
          end

          context 'when default_order_by is configured' do
            before { pagination_options.default_order_by = 'something_else' }

            it 'orders by the new default' do
              expect(pagination_options.order_by).to eq('something_else')
            end
          end
        end

        context 'when order_by is configured by the user' do
          context 'when default_order_by is configured' do
            before { pagination_options.default_order_by = 'something_else' }

            it 'uses the order_by param instead of the default' do
              expect(pagination_options.order_by).to eq(order_by)
            end
          end
        end
      end

      context 'when secondary_default_order_by is configured' do
        before do
          pagination_options.secondary_default_order_by = 'id'
          pagination_options.default_order_by = 'something'
        end

        context 'when order_by is not configured by the user' do
          it 'secondary_order_by returns the secondary_default_order_by' do
            pagination_options.order_by = nil
            expect(pagination_options.secondary_order_by).to eq('id')
          end
        end

        context 'when order_by is configured by the user' do
          it 'secondary_order_by returns nil' do
            pagination_options.order_by = 'first_name'
            expect(pagination_options.secondary_order_by).to be_nil
          end
        end

        context 'when order_by is configured by the user to be the same as the default' do
          it 'secondary_order_by returns the secondary_default_order_b' do
            pagination_options.order_by = 'something'
            expect(pagination_options.secondary_order_by).to eq('id')
          end
        end
      end

      context 'order_direction' do
        context 'when the order_direction is nil' do
          let(:order_direction) { nil }

          it 'defaults to asc' do
            expect(pagination_options.order_direction).to eq('asc')
          end
        end
      end

      it 'does not add default values when valid options are specified' do
        expect(pagination_options.page).to eq(page)
        expect(pagination_options.per_page).to eq(per_page)
        expect(pagination_options.order_by).to eq(order_by)
        expect(pagination_options.order_direction).to eq(order_direction)
      end
    end

    describe 'validations' do
      context 'when page is not an integer' do
        let(:params) { { page: 3.5 } }

        it 'is not valid' do
          message = PaginationOptions.new(params)

          expect(message).to be_valid
        end
      end

      context 'when per_page is not an integer' do
        let(:params) { { per_page: 3.5 } }

        it 'is not valid' do
          message = PaginationOptions.new(params)

          expect(message).to be_valid
        end
      end
    end

    describe 'ordering_configured?' do
      let(:pagination_options) { PaginationOptions.new(order_by:, order_direction:) }
      let(:order_by) { 'anything' }
      let(:order_direction) { 'desc' }

      it 'returns true when both are configured' do
        expect(pagination_options).to be_ordering_configured
      end

      context 'when order_by is not configured' do
        let(:order_by) { nil }

        it 'returns true' do
          expect(pagination_options).to be_ordering_configured
        end
      end

      context 'when order_direction is not configured' do
        let(:order_direction) { nil }

        it 'returns true' do
          expect(pagination_options).to be_ordering_configured
        end
      end

      context 'when order_by AND order_direction are not configured' do
        let(:order_by) { nil }
        let(:order_direction) { nil }

        it 'returns false' do
          expect(pagination_options).not_to be_ordering_configured
        end
      end
    end
  end
end
