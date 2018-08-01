require 'spec_helper'
require 'presenters/v3/pagination_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe PaginationPresenter do
    let(:presenter) { PaginationPresenter.new }
    let(:scheme) { TestConfig.config[:external_protocol] }
    let(:host) { TestConfig.config[:external_domain] }
    let(:link_prefix) { "#{scheme}://#{host}" }

    it 'has consistent presentation' do
      paginated_result = VCAP::CloudController::PaginatedResult.new(double(:results), 2, VCAP::CloudController::PaginationOptions.new(page: 1, per_page: 2))
      presented_pagination = presenter.present_pagination_hash(paginated_result, '/v3/pizza')
      presented_unpagination = presenter.present_unpagination_hash([1, 2], '/v3/flan')

      expect(presented_pagination.keys).to eq(presented_unpagination.keys)
    end

    describe '#present_pagination_hash' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:total_pages) { 2 }
      let(:options) { { page: page, per_page: per_page } }
      let(:pagination_options) { VCAP::CloudController::PaginationOptions.new(options) }
      let(:paginated_result) { VCAP::CloudController::PaginatedResult.new(double(:results), total_results, pagination_options) }
      let(:path) { '/v3/cloudfoundry/is-great' }

      it 'includes total_results' do
        result = presenter.present_pagination_hash(paginated_result, path)

        tr = result[:total_results]
        expect(tr).to eq(total_results)
      end

      it 'includes total_pages' do
        result = presenter.present_pagination_hash(paginated_result, path)

        tr = result[:total_pages]
        expect(tr).to eq(total_pages)
      end

      it 'includes first_url' do
        result = presenter.present_pagination_hash(paginated_result, path)

        first_url = result[:first][:href]
        expect(first_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
      end

      it 'includes last_url' do
        result = presenter.present_pagination_hash(paginated_result, path)

        last_url = result[:last][:href]
        expect(last_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?page=2&per_page=#{per_page}")
      end

      it 'sets first and last page to 1 if there is 1 page' do
        paginated_result = VCAP::CloudController::PaginatedResult.new([], 0, pagination_options)
        result = presenter.present_pagination_hash(paginated_result, path)

        last_url  = result[:last][:href]
        first_url = result[:first][:href]
        expect(last_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
        expect(first_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
      end

      it 'includes the filters in the result urls' do
        filters = double('filters', to_param_hash: { facet1: 'value1' })
        paginated_result = VCAP::CloudController::PaginatedResult.new([], 0, pagination_options)
        result = presenter.present_pagination_hash(paginated_result, path, filters)

        first_url = result[:first][:href]
        expect(first_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?facet1=value1&page=1&per_page=#{per_page}")
      end

      context 'when on the first page' do
        let(:page) { 1 }

        it 'sets previous_url to nil' do
          result = presenter.present_pagination_hash(paginated_result, path)

          previous_url = result[:previous]
          expect(previous_url).to be_nil
        end
      end

      context 'when NOT on the first page' do
        let(:page) { 2 }

        it 'includes previous_url' do
          result = presenter.present_pagination_hash(paginated_result, path)

          previous_url = result[:previous][:href]
          expect(previous_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
        end
      end

      context 'when on the last page' do
        let(:page) { total_results / per_page }
        let(:per_page) { 1 }

        it 'sets next_url to nil' do
          result = presenter.present_pagination_hash(paginated_result, path)

          next_url = result[:next]
          expect(next_url).to be_nil
        end
      end

      context 'when NOT on the last page' do
        let(:page) { 1 }
        let(:per_page) { 1 }

        it 'includes next_url' do
          result = presenter.present_pagination_hash(paginated_result, path)

          next_url = result[:next][:href]
          expect(next_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?page=2&per_page=#{per_page}")
        end
      end

      context 'pagination options' do
        let(:page) { 2 }
        let(:total_results) { 3 }
        let(:order_by) { 'id' }
        let(:order_direction) { 'asc' }
        let(:options) { { page: page, per_page: per_page, order_by: order_by, order_direction: order_direction } }

        it 'does not set order information if both order options are default' do
          result = presenter.present_pagination_hash(paginated_result, path)

          first_url = result[:first][:href]
          expect(first_url).to eq("#{link_prefix}/v3/cloudfoundry/is-great?page=1&per_page=#{per_page}")
        end

        context 'when order_by has been queried, it includes order_direction prefix' do
          let(:order_by) { 'created_at' }

          it 'sets the pagination options' do
            result = presenter.present_pagination_hash(paginated_result, path)

            first_page    = result[:first][:href]
            last_page     = result[:last][:href]
            next_page     = result[:next][:href]
            previous_page = result[:previous][:href]

            expect(first_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=1&per_page=#{per_page}")
            expect(last_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=3&per_page=#{per_page}")
            expect(next_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=3&per_page=#{per_page}")
            expect(previous_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=%2B#{order_by}&page=1&per_page=#{per_page}")
          end

          context 'when the order direction is desc' do
            let(:order_direction) { 'desc' }

            it 'sets the pagination options' do
              result = presenter.present_pagination_hash(paginated_result, path)

              first_page    = result[:first][:href]
              last_page     = result[:last][:href]
              next_page     = result[:next][:href]
              previous_page = result[:previous][:href]

              expect(first_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=1&per_page=#{per_page}")
              expect(last_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=3&per_page=#{per_page}")
              expect(next_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=3&per_page=#{per_page}")
              expect(previous_page).to eq("#{link_prefix}/v3/cloudfoundry/is-great?order_by=-#{order_by}&page=1&per_page=#{per_page}")
            end
          end
        end
      end
    end

    describe '#present_unpagination_hash' do
      let(:result) { ['thing_1', 'thing_2'] }
      let(:path) { '/v3/cloudfoundry/is-da-bomb' }
      let(:total_results) { 2 }

      it 'includes total_results' do
        unpaginated_result = presenter.present_unpagination_hash(result, path)

        tr = unpaginated_result[:total_results]
        expect(tr).to eq(total_results)
      end

      it 'includes the path as first_url' do
        unpaginated_result = presenter.present_unpagination_hash(result, path)

        first_url = unpaginated_result[:first][:href]
        expect(first_url).to eq('/v3/cloudfoundry/is-da-bomb')
      end

      it 'includes the path as last_url' do
        unpaginated_result = presenter.present_unpagination_hash(result, path)

        last_url = unpaginated_result[:last][:href]
        expect(last_url).to eq('/v3/cloudfoundry/is-da-bomb')
      end

      it 'does not include the next or previous page links' do
        unpaginated_result = presenter.present_unpagination_hash(result, path)

        next_page = unpaginated_result[:next]
        previous_page = unpaginated_result[:next]
        expect(next_page).to be_nil
        expect(previous_page).to be_nil
      end
    end
  end
end
