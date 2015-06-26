require 'spec_helper'

module VCAP::CloudController::RestController
  describe OrderApplicator do
    subject(:order_applicator) do
      OrderApplicator.new(opts)
    end

    def normalize_quotes(string)
      return string unless dataset.db.database_type == :postgres
      string.gsub '`', '"'
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
          expect(sql).to eq(normalize_quotes 'SELECT * FROM `test_models` ORDER BY `id` ASC')
        end
      end

      context 'when order_by is specified' do
        let(:opts) { { order_by: 'created_at' } }

        it 'orders by the specified column' do
          expect(sql).to eq(normalize_quotes 'SELECT * FROM `test_models` ORDER BY `created_at` ASC')
        end
      end

      context 'when order_by has multiple values' do
        let(:opts) { { order_by: ['created_at', 'id'] } }

        it 'orders by the specified column' do
          expect(sql).to eq(normalize_quotes 'SELECT * FROM `test_models` ORDER BY `created_at` ASC, `id` ASC')
        end
      end

      context 'when order_direction is specified' do
        let(:order_by) { {} }
        let(:opts) { { order_direction: 'desc' }.merge(order_by) }

        it 'orders by id in the specified direction' do
          expect(sql).to eq(normalize_quotes 'SELECT * FROM `test_models` ORDER BY `id` DESC')
        end

        context 'when order_by has multiple values' do
          let(:order_by) { { order_by: ['created_at', 'id'] } }

          it 'orders by the specified column' do
            expect(sql).to eq(normalize_quotes 'SELECT * FROM `test_models` ORDER BY `created_at` DESC, `id` DESC')
          end
        end
      end

      context 'when order_direction is specified with an invalid value' do
        let(:opts) { { order_direction: 'decs' } }

        it 'raises an error which makes sense to an api client' do
          expect { sql }.to raise_error(VCAP::Errors::ApiError)
        end
      end

      context 'when order_by is specified with an invalid column' do
        let(:opts) { { order_by: ['invalid_col', 'id'] } }

        it 'raises an error which makes sense to an api client' do
          expect { sql }.to raise_error(VCAP::Errors::ApiError)
        end
      end

      context 'when order_by is specified with an empty column' do
        let(:opts) { { order_by: ['id', '', 'created_at'] } }

        it 'raises an error which makes sense to an api client' do
          expect { sql }.to raise_error(VCAP::Errors::ApiError)
        end
      end
    end
  end
end
