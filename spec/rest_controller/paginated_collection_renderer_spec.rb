require 'spec_helper'

module VCAP::CloudController::RestController
  describe PaginatedCollectionRenderer do
    subject(:renderer) { described_class.new(eager_loader, serializer, renderer_opts) }
    let(:eager_loader) { SecureEagerLoader.new }
    let(:serializer) { PreloadedObjectSerializer.new }
    let(:renderer_opts) do
      {
        default_results_per_page: 100_000,
        max_results_per_page: 100_000,
        max_inline_relations_depth: 100_000,
      }
    end

    describe '#render_json' do
      let(:controller) { CarsController }
      let(:dataset) { Car.dataset }
      let(:path) { "/v2/cars" }
      let(:opts) { {} }
      let(:request_params) { {} }

      DB = Sequel.sqlite(':memory:')

      DB.create_table :cars do
        primary_key :id
        String :guid
        String :name
        Time :created_at
      end

      class Car < Sequel::Model(DB)
        attr_accessor :id, :created_at
        export_attributes :name
      end

      class CarsController < ModelController
        define_attributes {}
      end

      context 'when asked results_per_page is more than max results_per_page' do
        before { renderer_opts.merge!(max_results_per_page: 10) }
        before { opts.merge!(results_per_page: 11) }

        it 'raises BadQueryParameter error' do
          expect {
            subject.render_json(controller, dataset, path, opts, request_params)
          }.to raise_error(VCAP::Errors::BadQueryParameter, /results_per_page/)
        end
      end

      context 'when asked results_per_page equals to max results_per_page' do
        before { renderer_opts.merge!(max_results_per_page: 10) }
        before { opts.merge!(results_per_page: 10) }

        it 'renders json response' do
          result = subject.render_json(controller, dataset, path, opts, request_params)
          expect(result).to be_instance_of(String)
        end
      end

      context 'when asked results_per_page is less than max results_per_page' do
        before { renderer_opts.merge!(max_results_per_page: 10) }
        before { opts.merge!(results_per_page: 9) }

        it 'renders json response' do
          result = subject.render_json(controller, dataset, path, opts, request_params)
          expect(result).to be_instance_of(String)
        end
      end

      context 'when results_per_page were not specified' do
        before { renderer_opts.merge!(default_results_per_page: 1) }
        before { Car.create(name: "car-1"); Car.create(name: "car-2") }

        it 'renders limits number of results to default_results_per_page' do
          result = subject.render_json(controller, dataset, path, opts, request_params)
          expect(JSON.parse(result)["resources"].size).to eq(1)
        end
      end

      context 'when asked inline_relations_depth is more than max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 11) }

        it 'raises BadQueryParameter error' do
          expect {
            subject.render_json(controller, dataset, path, opts, request_params)
          }.to raise_error(VCAP::Errors::BadQueryParameter, /inline_relations_depth/)
        end
      end

      context 'when asked inline_relations_depth equals to max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 10) }

        it 'renders json response' do
          result = subject.render_json(controller, dataset, path, opts, request_params)
          expect(result).to be_instance_of(String)
        end
      end

      context 'when asked inline_relations_depth is less than max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 9) }

        it 'renders json response' do
          result = subject.render_json(controller, dataset, path, opts, request_params)
          expect(result).to be_instance_of(String)
        end
      end
    end
  end
end
