require 'spec_helper'

module VCAP::CloudController::RestController
  RSpec.describe ObjectRenderer do
    subject(:renderer) { described_class.new(eager_loader, serializer, renderer_opts) }
    let(:eager_loader) { SecureEagerLoader.new }
    let(:serializer) { PreloadedObjectSerializer.new }
    let(:renderer_opts) { { max_inline_relations_depth: 100_000 } }

    describe '#render_json' do
      let(:controller) { VCAP::CloudController::TestModelSecondLevelsController }
      let(:opts) { {} }

      let(:instance) { VCAP::CloudController::TestModelSecondLevel.make }

      context 'when asked inline_relations_depth is more than max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 11) }

        it 'raises BadQueryParameter error' do
          expect {
            subject.render_json(controller, instance, opts)
          }.to raise_error(CloudController::Errors::ApiError, /inline_relations_depth/)
        end
      end

      context 'when asked inline_relations_depth equals to max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 10) }

        it 'renders json response' do
          result = subject.render_json(controller, instance, opts)
          expect(result).to be_instance_of(String)
        end
      end

      context 'when asked inline_relations_depth is less than max inline_relations_depth' do
        before { renderer_opts.merge!(max_inline_relations_depth: 10) }
        before { opts.merge!(inline_relations_depth: 9) }

        it 'renders json response' do
          result = subject.render_json(controller, instance, opts)
          expect(result).to be_instance_of(String)
        end
      end

      describe 'object transformer' do
        let(:instance) { VCAP::CloudController::TestModel.make }
        let(:object_transformer) { double(:object_transformer) }

        before do
          renderer_opts[:object_transformer] = object_transformer
        end

        it 'accepts an optional object transformer that can mutate the rendered object' do
          expect(object_transformer).to receive(:transform) do |object|
            expect(object).to eq(instance)
            object.unique_value = 'bar'
          end

          result = MultiJson.load(subject.render_json(controller, instance, opts))
          expect(result['entity']['unique_value']).to eq('bar')
        end
      end
    end
  end
end
