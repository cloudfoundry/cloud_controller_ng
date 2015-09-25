require 'spec_helper'
require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  describe PaginationPresenter do
    describe '#present_pagination_hash' do
      let(:presenter) { PaginationPresenter.new }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:options) { { page: page, per_page: per_page } }
      let(:paginated_result) { PaginatedResult.new(double(:results), total_results, PaginationOptions.new(options)) }
      let(:base_url) { '/v3/cloudfoundry/is-great' }

      it 'includes total_results' do
        result = presenter.present_pagination_hash(paginated_result, base_url)

        tr = result[:total_results]
        expect(tr).to eq(total_results)
      end

      it 'includes first_url' do
        result = presenter.present_pagination_hash(paginated_result, base_url)

        first_url = result[:first][:href]
        expect(first_url).to eq("/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
      end

      it 'includes last_url' do
        result = presenter.present_pagination_hash(paginated_result, base_url)

        last_url = result[:last][:href]
        expect(last_url).to eq("/v3/cloudfoundry/is-great?page=2&per_page=#{per_page}")
      end

      it 'sets first and last page to 1 if there is 1 page' do
        paginated_result = PaginatedResult.new([], 0, PaginationOptions.new(options))
        result      = presenter.present_pagination_hash(paginated_result, base_url)

        last_url  = result[:last][:href]
        first_url = result[:first][:href]
        expect(last_url).to eq("/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
        expect(first_url).to eq("/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
      end

      it 'includes the filters in the result urls' do
        filters = double('filters', to_param_hash: { facet1: 'value1' })
        paginated_result = PaginatedResult.new([], 0, PaginationOptions.new(options))
        result      = presenter.present_pagination_hash(paginated_result, base_url, filters)

        first_url = result[:first][:href]
        expect(first_url).to eq("/v3/cloudfoundry/is-great?facet1=value1&page=1&per_page=#{per_page}")
      end

      context 'when on the first page' do
        let(:page) { 1 }

        it 'sets previous_url to nil' do
          result = presenter.present_pagination_hash(paginated_result, base_url)

          previous_url = result[:previous]
          expect(previous_url).to be_nil
        end
      end

      context 'when NOT on the first page' do
        let(:page) { 2 }

        it 'includes previous_url' do
          result = presenter.present_pagination_hash(paginated_result, base_url)

          previous_url = result[:previous][:href]
          expect(previous_url).to eq("/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
        end
      end

      context 'when on the last page' do
        let(:page) { total_results / per_page }
        let(:per_page) { 1 }

        it 'sets next_url to nil' do
          result = presenter.present_pagination_hash(paginated_result, base_url)

          next_url = result[:next]
          expect(next_url).to be_nil
        end
      end

      context 'when NOT on the last page' do
        let(:page) { 1 }
        let(:per_page) { 1 }

        it 'includes next_url' do
          result = presenter.present_pagination_hash(paginated_result, base_url)

          next_url = result[:next][:href]
          expect(next_url).to eq("/v3/cloudfoundry/is-great?page=2&per_page=#{per_page}")
        end
      end

      context 'pagination options' do
        let(:page) { 2 }
        let(:total_results) { 3 }
        let(:order_by) { 'id' }
        let(:order_direction) { 'asc' }
        let(:options) { { page: page, per_page: per_page, order_by: order_by, order_direction: order_direction } }

        it 'does not set order information if both order options are default' do
          result = presenter.present_pagination_hash(paginated_result, base_url)

          first_url = result[:first][:href]
          expect(first_url).to eq("/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
        end

        context 'when order_by has been queried, it includes order_direction prefix' do
          let(:order_by) { 'created_at' }

          it 'sets the pagination options' do
            result = presenter.present_pagination_hash(paginated_result, base_url)

            first_page    = result[:first][:href]
            last_page     = result[:last][:href]
            next_page     = result[:next][:href]
            previous_page = result[:previous][:href]

            expect(first_page).to eq("/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=1&per_page=#{per_page}")
            expect(last_page).to eq("/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=3&per_page=#{per_page}")
            expect(next_page).to eq("/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=3&per_page=#{per_page}")
            expect(previous_page).to eq("/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=1&per_page=#{per_page}")
          end

          context 'when the order direction is desc' do
            let(:order_direction) { 'desc' }

            it 'sets the pagination options' do
              result = presenter.present_pagination_hash(paginated_result, base_url)

              first_page    = result[:first][:href]
              last_page     = result[:last][:href]
              next_page     = result[:next][:href]
              previous_page = result[:previous][:href]

              expect(first_page).to eq("/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=1&per_page=#{per_page}")
              expect(last_page).to eq("/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=3&per_page=#{per_page}")
              expect(next_page).to eq("/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=3&per_page=#{per_page}")
              expect(previous_page).to eq("/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=1&per_page=#{per_page}")
            end
          end
        end
      end
    end
  end
end
