require 'spec_helper'
require 'messages/service_route_bindings_list_message'

module VCAP
  module CloudController
    RSpec.describe RouteBindingListFetcher do
      let(:fetcher) { RouteBindingListFetcher.new }

      describe 'fetch_all' do
        let!(:route_bindings) { Array.new(3) { RouteBinding.make } }
        it 'should return all route bindings' do
          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({})
          )

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_route_binding_guids = route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(expected_route_binding_guids)
        end

        it 'can be filtered by service_instance_guids' do
          filtered_route_bindings = route_bindings[0..-2]
          service_instance_guids = filtered_route_bindings.map(&:service_instance).map(&:guid).join(',')

          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({ 'service_instance_guids' => service_instance_guids })
          )

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_binding_guids = filtered_route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(expected_binding_guids)
        end

        it 'can be filtered by service_instance_names' do
          filtered_route_bindings = route_bindings[0..-2]
          service_instance_names = filtered_route_bindings.map(&:service_instance).map(&:name).join(',')

          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({ 'service_instance_names' => service_instance_names })
          )

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_binding_guids = filtered_route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(expected_binding_guids)
        end

        it 'can be filtered by route_guids' do
          filtered_route_bindings = route_bindings[0..-2]
          route_guids = filtered_route_bindings.map(&:route).map(&:guid).join(',')

          fetched_route_bindings = fetcher.fetch_all(
            ServiceRouteBindingsListMessage.from_params({ 'route_guids' => route_guids })
          )

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_binding_guids = filtered_route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(expected_binding_guids)
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

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          target_space_route_binding_guids = route_bindings_in_target_space.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(target_space_route_binding_guids)
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

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_binding_guids = filtered_route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(expected_binding_guids)
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

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_binding_guids = filtered_route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(expected_binding_guids)
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

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_binding_guids = filtered_route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to match_array(expected_binding_guids)
        end

        def make_other_route_bindings
          Array.new(3) { RouteBinding.make }
        end
      end
    end
  end
end
