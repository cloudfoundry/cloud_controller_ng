require 'spec_helper'
require 'presenters/v3/paginated_list_presenter'

module VCAP::CloudController
  describe PaginatedListPresenter do
    subject(:presenter) { described_class.new(dataset, base_url, message) }
    let(:set) { [Monkey.new('bobo'), Monkey.new('george')] }
    let(:dataset) { double('sequel dataset') }
    let(:message) { double('message', pagination_options: pagination_options, to_param_hash: {}) }
    let(:pagination_options) { double('pagination', per_page: 50, page: 1, order_by: 'monkeys', order_direction: 'asc') }
    let(:paginator) { instance_double(SequelPaginator) }
    let(:paginated_result) { PaginatedResult.new(set, 2, pagination_options) }

    before do
      allow(SequelPaginator).to receive(:new).and_return(paginator)
      allow(paginator).to receive(:get_page).with(dataset, pagination_options).and_return(paginated_result)
    end

    class Monkey
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    class MonkeyPresenter
      def initialize(monkey)
        @monkey = monkey
      end

      def to_hash
        {
          name: @monkey.name,
        }
      end
    end

    describe '#to_hash' do
      let(:base_url) { '/some/path' }

      it 'returns a paginated response for the set, with base_url only used in pagination' do
        expect(presenter.to_hash).to eq({
          pagination: {
            total_results: 2,
            total_pages: 1,
            first: { href: '/some/path?order_by=%2Bmonkeys&page=1&per_page=50' },
            last: { href: '/some/path?order_by=%2Bmonkeys&page=1&per_page=50' },
            next: nil,
            previous: nil
          },
          resources: [
            { name: 'bobo' },
            { name: 'george' },
          ]
        })
      end

      context 'with processes' do
        let(:process) { App.make }
        let(:set) { [process] }

        it 'uses the process presenter' do
          process_presenter = instance_double(ProcessPresenter, to_hash: { process: true })
          expect(ProcessPresenter).to receive(:new).with(process).and_return(process_presenter)
          expect(presenter.to_hash[:resources]).to eq([{ process: true }])
        end
      end
    end
  end
end
