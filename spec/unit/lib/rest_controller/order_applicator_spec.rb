require 'spec_helper'

module VCAP::CloudController::RestController
  RSpec.describe OrderApplicator do
    subject(:order_applicator) do
      OrderApplicator.new(opts)
    end

    def normalize_clause(string)
      case dataset.db.database_type
      when :postgres
        return string
      when :mysql
        return string.tr('`', '"')
      when :mssql
        src = string.split('`')
        dest = []
        src.each_index { |i|
          if i.even?
            dest.append(src[i])
          else
            dest.append("[#{src[i].upcase}]")
          end
        }
        return dest.join
      else
        return string
      end
    end

    describe '#apply' do
      let(:dataset) do
        VCAP::CloudController::TestModel.db[:test_models]
      end

      subject(:sql) do
        order_applicator.apply(dataset).sql
      end

      context 'when order_by and order_direction are unspecified' do
        let(:opts) { {} }

        it 'orders by id in ascending order' do
          expect(sql).to eq(normalize_clause('SELECT * FROM `test_models` ORDER BY `id` ASC'))
        end
      end

      context 'when order_by is specified' do
        let(:opts) { { order_by: 'field' } }

        it 'orders by the specified column' do
          expect(sql).to eq(normalize_clause('SELECT * FROM `test_models` ORDER BY `field` ASC'))
        end
      end

      context 'when order_by has multiple values' do
        let(:opts) { { order_by: ['field', 'id'] } }

        it 'orders by the specified column' do
          expect(sql).to eq(normalize_clause('SELECT * FROM `test_models` ORDER BY `field` ASC, `id` ASC'))
        end
      end

      context 'when order_direction is specified' do
        let(:order_by) { {} }
        let(:opts) { { order_direction: 'desc' }.merge(order_by) }

        it 'orders by id in the specified direction' do
          expect(sql).to eq(normalize_clause('SELECT * FROM `test_models` ORDER BY `id` DESC'))
        end

        context 'when order_by has multiple values' do
          let(:order_by) { { order_by: ['field', 'id'] } }

          it 'orders by the specified column' do
            expect(sql).to eq(normalize_clause('SELECT * FROM `test_models` ORDER BY `field` DESC, `id` DESC'))
          end
        end
      end

      context 'when order_direction is specified with an invalid value' do
        let(:opts) { { order_direction: 'decs' } }

        it 'raises an error which makes sense to an api client' do
          expect { sql }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end
  end
end
