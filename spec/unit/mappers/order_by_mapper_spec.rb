require 'spec_helper'
require 'mappers/order_by_mapper'

module VCAP::CloudController
  RSpec.describe OrderByMapper do
    describe '#from-param' do
      let(:order_by) { 'name' }

      it 'returns the modifed order_by and order_direction "nil"' do
        expect(OrderByMapper.from_param(order_by)).to eq(['name', nil])
      end

      context 'with a user-provided direction' do
        context 'when the provided direction is "+"' do
          let(:order_by) { '+name' }

          it 'returns the modifed order_by and order_direction "asc"' do
            expect(OrderByMapper.from_param(order_by)).to eq(['name', 'asc'])
          end
        end

        context 'when the provided direction is "-"' do
          let(:order_by) { '-name' }

          it 'returns the modifed order_by and order_direction "desc"' do
            expect(OrderByMapper.from_param(order_by)).to eq(['name', 'desc'])
          end
        end
      end
    end
    describe '#to_param_hash' do
      let(:order_by) { 'name' }
      let(:order_direction) { 'desc' }

      it 'returns a hash where the prefix of order_by describes the order_direction' do
        expect(OrderByMapper.to_param_hash(order_by, order_direction)).
          to eq({ order_by: '-name' })
      end

      context 'when order_by is `id`' do
        let(:order_by) { 'id' }
        it 'returns an empty hash' do
          expect(OrderByMapper.to_param_hash(order_by, order_direction)).
            to eq({})
        end
      end
    end
  end
end
