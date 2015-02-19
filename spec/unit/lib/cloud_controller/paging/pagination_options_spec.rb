require 'spec_helper'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  describe PaginationOptions do
    describe '.from_params'
    context 'default values' do
      let(:pagination_options) { PaginationOptions.new(options) }
      let(:options) { { page: page, per_page: per_page, order_by: order_by, order_direction: order_direction } }
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

        context 'when page is less than or equal to zero' do
          let(:page) { 0 }

          it 'defaults to the first page if page is 0' do
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

        context 'when per_page is less than or equal to zero' do
          let(:per_page) { 0 }

          it 'defaults to 50' do
            expect(pagination_options.per_page).to eq(50)
          end
        end

        context 'when per_page is greater than the max' do
          let(:per_page) { 10000 }

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
        end
      end

      context 'order_direction' do
        context 'when the order_direction is nil' do
          let(:order_direction) { nil }

          it 'defaults to asc' do
            expect(pagination_options.order_direction).to eq('asc')
          end
        end

        context 'when the order_direction is invalid' do
          let(:order_direction) { 'foobar' }

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
  end
end
