require 'spec_helper'
require 'messages/service_route_bindings_list_message'

module VCAP
  module CloudController
    RSpec.describe RouteBindingListFetcher do
      let(:fetcher) { described_class }

      describe 'fetch_all' do
        let!(:route_bindings) { Array.new(3) { RouteBinding.make } }
        it 'should return all route bindings' do
          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({})
          )

          expect_binding_guids(fetched_route_bindings, route_bindings)
        end

        it 'can be filtered by service_instance_guids' do
          filtered_route_bindings = route_bindings[0..-2]
          service_instance_guids = filtered_route_bindings.map(&:service_instance).map(&:guid).join(',')

          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({ 'service_instance_guids' => service_instance_guids })
          )

          expect_binding_guids(fetched_route_bindings, filtered_route_bindings)
        end

        it 'can be filtered by service_instance_names' do
          filtered_route_bindings = route_bindings[0..-2]
          service_instance_names = filtered_route_bindings.map(&:service_instance).map(&:name).join(',')

          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({ 'service_instance_names' => service_instance_names })
          )

          expect_binding_guids(fetched_route_bindings, filtered_route_bindings)
        end

        it 'can be filtered by route_guids' do
          filtered_route_bindings = route_bindings[0..-2]
          route_guids = filtered_route_bindings.map(&:route).map(&:guid).join(',')

          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({ 'route_guids' => route_guids })
          )

          expect_binding_guids(fetched_route_bindings, filtered_route_bindings)
        end

        it 'eager loads the specified resources' do
          dataset = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({}),
            eager_loaded_associations: [:labels]
          )

          expect(dataset.all.first.associations.key?(:labels)).to be true
          expect(dataset.all.first.associations.key?(:annotations)).to be false
        end

        context 'can be filtered by label selector' do
          before do
            RouteBindingLabelModel.make(key_name: 'fruit', value: 'strawberry', route_binding: route_bindings[0])
            RouteBindingLabelModel.make(key_name: 'fruit', value: 'strawberry', route_binding: route_bindings[1])
            RouteBindingLabelModel.make(key_name: 'fruit', value: 'lemon', route_binding: route_bindings[2])
          end

          it 'returns instances with matching labels' do
            filtered_route_bindings = route_bindings[0..1]

            fetched_route_bindings = fetcher.fetch_all(
              ServiceRouteBindingsListMessage.from_params({ 'label_selector' => 'fruit=strawberry' })
            )

            expect_binding_guids(fetched_route_bindings, filtered_route_bindings)
          end
        end
      end

      describe 'fetch_some' do
        let(:target_space) { Space.make }

        before do
          make_other_route_bindings
        end

        it 'should return route bindings related to a set of space guids' do
          service_instance_in_target_space = UserProvidedServiceInstance.make(:routing, space: target_space)
          route_bindings_in_target_space = Array.new(3) { RouteBinding.make(service_instance: service_instance_in_target_space) }

          fetched_route_bindings = fetcher.fetch_some(
            ServiceRouteBindingsListMessage.from_params({}),
            space_guids: [target_space.guid]
          )

          expect_binding_guids(fetched_route_bindings, route_bindings_in_target_space)
        end

        it 'can be filtered by service_instance_guids' do
          route_bindings_in_target_space = Array.new(3) do
            service_instance_in_target_space = UserProvidedServiceInstance.make(:routing, space: target_space)
            RouteBinding.make(service_instance: service_instance_in_target_space)
          end

          filtered_route_bindings = route_bindings_in_target_space[0..-2]
          service_instance_guids = filtered_route_bindings.map(&:service_instance).map(&:guid).join(',')

          fetched_route_bindings = fetcher.fetch_some(
            ServiceRouteBindingsListMessage.from_params({ 'service_instance_guids' => service_instance_guids }),
            space_guids: [target_space.guid]
          )

          expect_binding_guids(fetched_route_bindings, filtered_route_bindings)
        end

        it 'can be filtered by service_instance_names' do
          route_bindings_in_target_space = Array.new(3) do
            service_instance_in_target_space = UserProvidedServiceInstance.make(:routing, space: target_space)
            RouteBinding.make(service_instance: service_instance_in_target_space)
          end

          filtered_route_bindings = route_bindings_in_target_space[0..-2]
          service_instance_names = filtered_route_bindings.map(&:service_instance).map(&:name).join(',')

          fetched_route_bindings = fetcher.fetch_some(
            ServiceRouteBindingsListMessage.from_params({ 'service_instance_names' => service_instance_names }),
            space_guids: [target_space.guid]
          )

          expect_binding_guids(fetched_route_bindings, filtered_route_bindings)
        end

        it 'can be filtered by route_guids' do
          route_bindings_in_target_space = Array.new(3) do
            service_instance_in_target_space = UserProvidedServiceInstance.make(:routing, space: target_space)
            RouteBinding.make(service_instance: service_instance_in_target_space)
          end

          filtered_route_bindings = route_bindings_in_target_space[0..-2]
          route_guids = filtered_route_bindings.map(&:route).map(&:guid).join(',')

          fetched_route_bindings = fetcher.fetch_some(
            ServiceRouteBindingsListMessage.from_params({ 'route_guids' => route_guids }),
            space_guids: [target_space.guid]
          )

          expect_binding_guids(fetched_route_bindings, filtered_route_bindings)
        end

        it 'eager loads the specified resources' do
          RouteBinding.make(service_instance: UserProvidedServiceInstance.make(:routing, space: target_space))

          dataset = fetcher.fetch_some(
            ServiceRouteBindingsListMessage.from_params({}),
            space_guids: [target_space.guid],
            eager_loaded_associations: [:labels]
          )

          expect(dataset.all.first.associations.key?(:labels)).to be true
          expect(dataset.all.first.associations.key?(:annotations)).to be false
        end

        def make_other_route_bindings
          Array.new(3) { RouteBinding.make }
        end
      end

      def expect_binding_guids(fetched_route_bindings, expected_route_bindings)
        expect(fetched_route_bindings.map(&:guid)).to match_array(expected_route_bindings.map(&:guid))
      end
    end
  end
end
