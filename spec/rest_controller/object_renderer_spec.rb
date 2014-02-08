require 'spec_helper'

module VCAP::CloudController::RestController
  describe ObjectRenderer do
    subject(:renderer) { described_class.new(eager_loader, serializer, renderer_opts) }
    let(:eager_loader) { SecureEagerLoader.new }
    let(:serializer) { PreloadedObjectSerializer.new }
    let(:renderer_opts) { { max_inline_relations_depth: 100_000 } }

    describe '#render_json' do
      let(:controller) { CarsController }
      let(:obj) { Car.create { |c| c.id = 1; c.name = 'car-1' } }
      let(:opts) { {} }

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
        alias_method :model, :class
      end

      class CarsController < ModelController
        define_attributes {}
      end

      context 'when asked inline_relations_depth is more than max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 11) }

        it 'raises BadQueryParameter error' do
          expect {
            subject.render_json(controller, obj, opts)
          }.to raise_error(VCAP::Errors::BadQueryParameter, /inline_relations_depth/)
        end
      end

      context 'when asked inline_relations_depth equals to max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 10) }

        it 'renders json response' do
          result = subject.render_json(controller, obj, opts)
          expect(result).to be_instance_of(String)
        end
      end

      context 'when asked inline_relations_depth is less than max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 9) }

        it 'renders json response' do
          result = subject.render_json(controller, obj, opts)
          expect(result).to be_instance_of(String)
        end
      end
    end
  end
end
