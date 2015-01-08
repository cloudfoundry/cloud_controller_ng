require 'spec_helper'
require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  describe PaginationPresenter do
    describe '#present_pagination_hash' do
      let(:presenter) { PaginationPresenter.new }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(double(:results), total_results, PaginationOptions.new(page, per_page)) }
      let(:base_url) { '/cloudfoundry/is-great' }

      it 'includes total_results' do
        result = presenter.present_pagination_hash(paginated_result, base_url)

        tr = result[:total_results]
        expect(tr).to eq(total_results)
      end

      it 'includes first_url' do
        result = presenter.present_pagination_hash(paginated_result, base_url)

        first_url = result[:first][:href]
        expect(first_url).to eq("/cloudfoundry/is-great?page=1&per_page=#{per_page}")
      end

      it 'includes last_url' do
        result = presenter.present_pagination_hash(paginated_result, base_url)

        last_url = result[:last][:href]
        expect(last_url).to eq("/cloudfoundry/is-great?page=2&per_page=#{per_page}")
      end

      it 'sets first and last page to 1 if there is 1 page' do
        paginated_result = PaginatedResult.new([], 0, PaginationOptions.new(page, per_page))
        result      = presenter.present_pagination_hash(paginated_result, base_url)

        last_url  = result[:last][:href]
        first_url = result[:first][:href]
        expect(last_url).to eq("/cloudfoundry/is-great?page=1&per_page=#{per_page}")
        expect(first_url).to eq("/cloudfoundry/is-great?page=1&per_page=#{per_page}")
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
          expect(previous_url).to eq("/cloudfoundry/is-great?page=1&per_page=#{per_page}")
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
          expect(next_url).to eq("/cloudfoundry/is-great?page=2&per_page=#{per_page}")
        end
      end
    end
  end
end
