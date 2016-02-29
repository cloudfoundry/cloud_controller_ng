require 'spec_helper'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  describe PaginationOptions do
    describe '.from_params' do
      let(:params) do
        {
          'page'            => 4,
          'per_page'        => 56,
          'order_by'        => '+updated_at',
          'extra'           => 'stuff'
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
          params['order_by'] = '-updated_at'
          result = PaginationOptions.from_params(params)

          expect(result.order_by).to eq('updated_at')
          expect(result.order_direction).to eq('desc')
        end

        it 'defaults to ascending' do
          params['order_by'] = 'updated_at'
          result = PaginationOptions.from_params(params)

          expect(result.order_by).to eq('updated_at')
          expect(result.order_direction).to eq('asc')
        end
      end

      it 'removes pagination options from params' do
        PaginationOptions.from_params(params)

        expect(params).to_not have_key('page')
        expect(params).to_not have_key('per_page')
        expect(params).to_not have_key('order_by')
        expect(params).to_not have_key('order_direction')
        expect(params).to have_key('extra')
      end
    end

    describe 'default values' do
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
      describe 'page' do
        context 'when page is not an number' do
          let(:params) { { page: 'silly string thing' } }

          it 'is not valid' do
            message = PaginationOptions.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('is not a number')
          end
        end

        context 'when page is not an integer' do
          let(:params) { { page: 3.5 } }

          it 'is not valid' do
            message = PaginationOptions.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('must be an integer')
          end
        end

        context 'when page is less than 1' do
          let(:params) { { page: 0 } }

          it 'is not valid' do
            message = PaginationOptions.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('must be greater than 0')
          end
        end
      end

      describe 'per_page' do
        context 'when per_page is not an number' do
          let(:params) { { per_page: 'silly string thing' } }

          it 'is not valid' do
            message = PaginationOptions.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('must be between 1 and 5000')
          end
        end

        context 'when per_page is not an integer' do
          let(:params) { { per_page: 3.5 } }

          it 'is not valid' do
            message = PaginationOptions.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('must be between 1 and 5000')
          end
        end

        context 'when per_page is less than 1' do
          let(:params) { { per_page: 0 } }

          it 'is not valid' do
            message = PaginationOptions.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('must be between 1 and 5000')
          end
        end

        context 'when per_page is greater than 5000' do
          let(:params) { { per_page: 10000 } }

          it 'is not valid' do
            message = PaginationOptions.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('must be between 1 and 5000')
          end
        end
      end

      describe 'order_by' do
        let(:params1) { { order_by: 'created_at' } }
        let(:params2) { { order_by: 'updated_at' } }
        let(:params3) { { order_by: 'id' } }
        let(:invalid_params) { { order_by: 'blahblahblah' } }

        it 'must be one of the valid strings' do
          message1 = PaginationOptions.new(params1)
          message2 = PaginationOptions.new(params2)
          message3 = PaginationOptions.new(params3)
          invalid_message = PaginationOptions.new(invalid_params)

          expect(message1).to be_valid
          expect(message2).to be_valid
          expect(message3).to be_valid
          expect(invalid_message).to_not be_valid
          expect(invalid_message.errors.full_messages[0]).to include("can only be 'created_at' or 'updated_at'")
        end
      end

      describe 'order_direction' do
        let(:params1) { { order_direction: 'asc' } }
        let(:params2) { { order_direction: 'desc' } }
        let(:params3) { { order_direction: 'blahblahblah' } }

        it 'must be one of the valid strings' do
          message1 = PaginationOptions.new(params1)
          message2 = PaginationOptions.new(params2)
          message3 = PaginationOptions.new(params3)

          expect(message1).to be_valid
          expect(message2).to be_valid
          expect(message3).to_not be_valid
          expect(message3.errors.full_messages[0]).to include("can only be 'asc' or 'desc'")
        end
      end
    end
  end
end
