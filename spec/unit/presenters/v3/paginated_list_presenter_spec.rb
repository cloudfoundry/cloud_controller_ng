require 'spec_helper'
require 'presenters/v3/paginated_list_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe PaginatedListPresenter do
    subject(:presenter) { described_class.new(dataset, base_url, message) }
    let(:set) { [Monkey.new('bobo'), Monkey.new('george')] }
    let(:dataset) { double('sequel dataset') }
    let(:message) { double('message', pagination_options: pagination_options, to_param_hash: {}) }
    let(:pagination_options) { double('pagination', per_page: 50, page: 1, order_by: 'monkeys', order_direction: 'asc') }
    let(:paginator) { instance_double(VCAP::CloudController::SequelPaginator) }
    let(:paginated_result) { VCAP::CloudController::PaginatedResult.new(set, 2, pagination_options) }

    before do
      allow(VCAP::CloudController::SequelPaginator).to receive(:new).and_return(paginator)
      allow(paginator).to receive(:get_page).with(dataset, pagination_options).and_return(paginated_result)
    end

    class Monkey
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    class MonkeyPresenter < BasePresenter
      def to_hash
        {
          name: @resource.name,
        }
      end
    end

    describe '#to_hash' do
      let(:base_url) { '/some/path' }

      it 'returns a paginated response for the set, with base_url only used in pagination' do
        expect(presenter.to_hash).to eq({
          pagination: {
            total_results: 2,
            total_pages:   1,
            first:         { href: '/some/path?order_by=%2Bmonkeys&page=1&per_page=50' },
            last:          { href: '/some/path?order_by=%2Bmonkeys&page=1&per_page=50' },
            next:          nil,
            previous:      nil
          },
          resources:  [
            { name: 'bobo' },
            { name: 'george' },
          ]
        })
      end

      it 'sends false for show_secrets' do
        allow(MonkeyPresenter).to receive(:new).and_call_original
        presenter.to_hash
        expect(MonkeyPresenter).to have_received(:new).
          with(anything, show_secrets: false, censored_message: BasePresenter::REDACTED_LIST_MESSAGE).exactly(set.count).times
      end
    end
  end
end
