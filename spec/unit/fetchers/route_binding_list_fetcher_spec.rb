require 'spec_helper'

module VCAP
  module CloudController
    RSpec.describe RouteBindingListFetcher do
      let(:fetcher) { RouteBindingListFetcher.new }

      describe 'fetch_all' do
        it 'should return all route bindings' do
          route_bindings = Array.new(3) { RouteBinding.make }

          fetched_route_bindings = fetcher.fetch_all

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          expected_route_binding_guids = route_bindings.map(&:guid)
          expect(fetched_route_binding_guids).to eq(expected_route_binding_guids)
        end
      end

      describe 'fetch_some' do
        it 'it should return route bindings related to a set of space guids' do
          target_space = Space.make
          service_instance_in_target_space = UserProvidedServiceInstance.make(:routing, space: target_space)
          make_other_route_bindings
          route_bindings_in_target_space = Array.new(3) { RouteBinding.make(service_instance: service_instance_in_target_space) }

          fetched_route_bindings = fetcher.fetch_some(space_guids: [target_space.guid])

          fetched_route_binding_guids = fetched_route_bindings.map(&:guid)
          target_space_route_binding_guids = route_bindings_in_target_space.map(&:guid)
          expect(fetched_route_binding_guids).to eq(target_space_route_binding_guids)
        end

        def make_other_route_bindings
          Array.new(3) { RouteBinding.make }
        end
      end
    end
  end
end
