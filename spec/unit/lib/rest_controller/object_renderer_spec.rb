require 'spec_helper'

module VCAP::CloudController::RestController
  RSpec.describe ObjectRenderer do
    subject(:renderer) { ObjectRenderer.new(eager_loader, serializer, renderer_opts) }
    let(:eager_loader) { SecureEagerLoader.new }
    let(:serializer) { PreloadedObjectSerializer.new }
    let(:renderer_opts) { { max_inline_relations_depth: 100_000 } }

    describe '#render_json' do
      let(:controller) { VCAP::CloudController::TestModelSecondLevelsController }
      let(:opts) { {} }

      let(:instance) { VCAP::CloudController::TestModelSecondLevel.make }

      context 'when asked inline_relations_depth is more than max inline_relations_depth' do
        before do
          renderer_opts.merge!(max_inline_relations_depth: 10)
          opts.merge!(inline_relations_depth: 11)
        end

        it 'raises BadQueryParameter error' do
          expect do
            subject.render_json(controller, instance, opts)
          end.to raise_error(CloudController::Errors::ApiError, /inline_relations_depth/)
        end
      end

      context 'when asked inline_relations_depth equals to max inline_relations_depth' do
        before do
          renderer_opts.merge!(max_inline_relations_depth: 10)
          opts.merge!(inline_relations_depth: 10)
        end

        it 'renders json response' do
          result = subject.render_json(controller, instance, opts)
          expect(result).to be_instance_of(String)
        end
      end

      context 'when asked inline_relations_depth is less than max inline_relations_depth' do
        before do
          renderer_opts.merge!(max_inline_relations_depth: 10)
          opts.merge!(inline_relations_depth: 9)
        end

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

      context 'service_plan renderer' do
        let(:user) { VCAP::CloudController::User.make }
        let(:organization) { VCAP::CloudController::Organization.make }
        let(:space) { VCAP::CloudController::Space.make(organization:) }
        let(:controller) { VCAP::CloudController::ServicePlansController }
        let(:opts) { {} }
        let(:broker) { VCAP::CloudController::ServiceBroker.make }
        let(:service) { VCAP::CloudController::Service.make(service_broker: broker) }
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service, public: false, active: false) }

        before do
          space.organization.add_user(user)
          space.add_developer(user)
          set_current_user_as_admin
        end

        it 'renders a service plan accessible via user\'s service instance only' do
          VCAP::CloudController::ManagedServiceInstance.make(space:, service_plan:)
          set_current_user(user)
          result = MultiJson.load(subject.render_json_with_read_privileges(controller, service_plan, opts))
          expect(result['entity']['service_guid']).to eq(service.guid)
        end
      end
    end
  end
end
