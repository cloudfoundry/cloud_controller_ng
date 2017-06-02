require 'spec_helper'

module VCAP::CloudController::RestController
  RSpec.describe PaginatedCollectionRenderer do
    let(:controller) { VCAP::CloudController::TestModelsController }
    let(:dataset) { VCAP::CloudController::TestModel.dataset }

    subject(:paginated_collection_renderer) { PaginatedCollectionRenderer.new(eager_loader, serializer, renderer_opts) }

    let(:eager_loader) { SecureEagerLoader.new }
    let(:serializer) { PreloadedObjectSerializer.new }
    let(:renderer_opts) do
      {
        default_results_per_page: default_results_per_page,
        max_results_per_page: max_results_per_page,
        max_inline_relations_depth: max_inline_relations_depth,
        collection_transformer: collection_transformer
      }
    end
    let(:default_results_per_page) { 100_000 }
    let(:max_results_per_page) { 100_000 }
    let(:max_inline_relations_depth) { 100_000 }
    let(:collection_transformer) { nil }

    describe '#render_json' do
      let(:opts) do
        {
            page: page,
            results_per_page: results_per_page,
            inline_relations_depth: inline_relations_depth,
            orphan_relations: orphan_relations,
            exclude_relations: exclude_relations,
            include_relations: include_relations
        }
      end
      let(:page) { nil }
      let(:inline_relations_depth) { nil }
      let(:results_per_page) { nil }
      let(:orphan_relations) { nil }
      let(:exclude_relations) { nil }
      let(:include_relations) { nil }

      subject(:render_json_call) do
        paginated_collection_renderer.render_json(controller, dataset, '/v2/cars', opts, {})
      end

      context 'when one of the objects serializes to nil' do
        let(:dataset) { VCAP::CloudController::TestModel.dataset }
        let(:serializer) { instance_double(PreloadedObjectSerializer) }

        before do
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          counter = 0
          allow(serializer).to receive(:serialize).with(any_args) do
            if counter == 0
              counter += 1
              nil
            else
              'fake-serialization'
            end
          end
        end

        it 'excludes that object from the serialization' do
          expect(JSON.parse(render_json_call)['resources'].size).to eq(1)
        end
      end

      context 'when results_per_page' do
        context 'is more than max results_per_page' do
          let(:max_results_per_page) { 10 }
          let(:results_per_page) { 11 }

          it 'raises ApiError error' do
            expect { render_json_call }.to raise_error(CloudController::Errors::ApiError, /results_per_page/)
          end
        end

        context 'equals to max results_per_page' do
          let(:max_results_per_page) { 10 }
          let(:results_per_page) { 10 }

          it 'renders json response' do
            expect(render_json_call).to be_instance_of(String)
          end
        end

        context 'is less than max results_per_page' do
          let(:max_results_per_page) { 10 }
          let(:results_per_page) { 9 }

          it 'renders json response' do
            expect(render_json_call).to be_instance_of(String)
          end
        end

        context 'was not specified' do
          before do
            VCAP::CloudController::TestModel.make
            VCAP::CloudController::TestModel.make
          end

          let(:default_results_per_page) { 1 }

          it 'renders limits number of results to default_results_per_page' do
            expect(JSON.parse(render_json_call)['resources'].size).to eq(1)
          end
        end
      end

      context 'when inline_relations_depth' do
        context 'is more than max inline_relations_depth' do
          let(:max_inline_relations_depth) { 10 }
          let(:inline_relations_depth) { 11 }

          it 'raises BadQueryParameter error' do
            expect {
              render_json_call
            }.to raise_error(CloudController::Errors::ApiError, /inline_relations_depth/)
          end
        end

        context 'is equal to max inline_relations_depth' do
          let(:max_inline_relations_depth) { 10 }
          let(:inline_relations_depth) { 10 }

          it 'renders json response' do
            expect(render_json_call).to be_instance_of(String)
          end
        end

        context 'is less than max inline_relations_depth' do
          let(:max_inline_relations_depth) { 10 }
          let(:inline_relations_depth) { 9 }

          it 'renders json response' do
            expect(render_json_call).to be_instance_of(String)
          end
        end
      end

      context 'when orphan_relations' do
        before do
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
        end

        let(:page) { 2 }
        let(:results_per_page) { 1 }

        context 'is specified' do
          let(:orphan_relations) { 1 }

          it 'renders json response with orphans' do
            result = render_json_call
            expect(result).to be_instance_of(String)
            orphans = JSON.parse(result)['orphans']
            expect(orphans).to eql({})
          end

          it 'includes orphan-relations in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to include("orphan-relations=#{orphan_relations}")
            expect(next_url).to include("orphan-relations=#{orphan_relations}")
          end
        end

        context 'is not specified' do
          let(:orphan_relations) { nil }

          it 'renders json response without orphans' do
            result = render_json_call
            expect(result).to be_instance_of(String)
            expect(JSON.parse(result)).not_to have_key('orphans')
          end

          it 'does not include orphan-relations in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to_not include('orphan-relations')
            expect(next_url).to_not include('orphan-relations')
          end
        end
      end

      context 'when exclude-relations' do
        before do
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
        end

        let(:opts) do
          {
            results_per_page: 1,
            exclude_relations: exclude_relations,
            page: 2
          }
        end

        context 'is specified' do
          let(:exclude_relations) { 'relation1,relation2' }

          it 'includes exclude-relations in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to include("exclude-relations=#{exclude_relations}")
            expect(next_url).to include("exclude-relations=#{exclude_relations}")
          end
        end

        context 'is not specified' do
          let(:exclude_relations) { nil }

          it 'does not include exclude-relations in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to_not include('exclude-relations')
            expect(next_url).to_not include('exclude-relations')
          end
        end
      end

      context 'when include-relations' do
        before do
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
        end

        let(:opts) do
          {
            results_per_page: 1,
            include_relations: include_relations,
            page: 2
          }
        end

        context 'is specified' do
          let(:include_relations) { 'relation1,relation2' }

          it 'includes include-relations in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to include("include-relations=#{include_relations}")
            expect(next_url).to include("include-relations=#{include_relations}")
          end
        end

        context 'is not specified' do
          let(:include_relations) { nil }

          it 'does not include include-relations in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to_not include('include-relations')
            expect(next_url).to_not include('include-relations')
          end
        end
      end

      context 'order-direction' do
        before do
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
        end

        let(:opts) do
          {
            results_per_page: 1,
            order_direction: order_direction,
            page: 2
          }
        end

        context 'when not specified' do
          let(:opts) do
            {
              results_per_page: 1,
              page: 2
            }
          end

          it 'defaults to asc' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to include('order-direction=asc')
            expect(next_url).to include('order-direction=asc')
          end
        end

        context 'when ascending' do
          let(:order_direction) { 'asc' }

          it 'includes order-direction in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to include("order-direction=#{order_direction}")
            expect(next_url).to include("order-direction=#{order_direction}")
          end
        end

        context 'when descending' do
          let(:order_direction) { 'desc' }

          it 'includes order-direction in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to include("order-direction=#{order_direction}")
            expect(next_url).to include("order-direction=#{order_direction}")
          end
        end
      end

      context 'order-by' do
        before do
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
        end

        let(:opts) do
          {
            results_per_page: 1,
            order_by: order_by_param,
            page: 2
          }
        end

        context 'when not specified' do
          let(:opts) do
            {
              results_per_page: 1,
              page: 2
            }
          end

          it 'does not include order-by in url params' do
            next_url = JSON.parse(render_json_call)['next_url']
            expect(next_url).to_not include('order-by')
          end
        end

        context 'when it is specified' do
          let(:order_by_param) { 'sortable_value' }

          it 'includes order-by in next_url and prev_url' do
            prev_url = JSON.parse(render_json_call)['prev_url']
            next_url = JSON.parse(render_json_call)['next_url']
            expect(prev_url).to include("order-by=#{order_by_param}")
            expect(next_url).to include("order-by=#{order_by_param}")
          end
        end
      end

      context 'when collection_transformer is given' do
        let(:collection_transformer) { double('collection_transformer') }
        let!(:test_model) { VCAP::CloudController::TestModel.make }

        it 'passes the populated dataset to the transformer' do
          expect(collection_transformer).to receive(:transform) do |collection|
            expect(collection).to eq([test_model])
          end

          render_json_call
        end

        it 'serializes the transformed collection' do
          expect(collection_transformer).to receive(:transform) do |collection|
            collection.first.unique_value = 'test_value'
          end

          expect(JSON.parse(render_json_call)['resources'][0]['entity']['unique_value']).to eq('test_value')
        end
      end

      context 'when request_params are given' do
        let(:results_per_page) { 1 }
        before do
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          VCAP::CloudController::TestModel.make
          opts[:q] = 'organization_guid:1234'
        end

        context 'at page 1' do
          let(:page) { 1 }
          it 'has a next link with the q' do
            result = JSON.parse(render_json_call)
            expect(result['prev_url']).to be_nil
            expect(result['next_url']).to include('q=organization_guid:1234')
          end
        end

        context 'at page 2' do
          let(:page) { 2 }
          it 'has a prev link with the q' do
            result = JSON.parse(render_json_call)
            expect(result['prev_url']).to include('q=organization_guid:1234')
            expect(result['next_url']).to include('q=organization_guid:1234')
          end
        end

        context 'at page 3' do
          let(:page) { 2 }
          it 'has a prev link with the q' do
            result = JSON.parse(render_json_call)
            expect(result['prev_url']).to include('q=organization_guid:1234')
            expect(result['next_url']).to include('q=organization_guid:1234')
          end
        end
      end
    end
  end
end
