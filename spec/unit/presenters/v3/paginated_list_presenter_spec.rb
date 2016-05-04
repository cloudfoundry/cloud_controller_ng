require 'spec_helper'
require 'presenters/v3/paginated_list_presenter'

module VCAP::CloudController
  describe PaginatedListPresenter do
    subject(:presenter) { described_class.new(dataset, base_url) }
    let(:dataset) {
      double('sequel dataset',
             records: set,
             pagination_options: double('pagination', per_page: 50, page: 1, order_by: 'monkeys', order_direction: 'asc'),
             total: 2
            )
    }
    let(:set) { [Monkey.new('bobo'), Monkey.new('george')] }

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
