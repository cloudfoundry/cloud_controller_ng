require 'spec_helper'
require 'decorators/include_route_policies_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRoutePoliciesDecorator do
    subject(:decorator) { IncludeRoutePoliciesDecorator }

    let(:space) { Space.make }
    let(:domain) { SharedDomain.make }
    let(:route1) { Route.make(space: space, domain: domain) }
    let(:route2) { Route.make(space: space, domain: domain) }

    it 'decorates the given hash with route_policies from routes' do
      route_policy1 = RoutePolicy.create(route: route1, source_type: 'app', source_guid: 'app-guid-1')
      route_policy2 = RoutePolicy.create(route: route2, source_type: 'app', source_guid: 'app-guid-2')
      undecorated_hash = { i_am: 'tim' }
      hash = subject.decorate(undecorated_hash, [route1, route2])
      expect(hash[:i_am]).to eq('tim')
      expect(hash[:included][:route_policies]).to contain_exactly(
        Presenters::V3::RoutePolicyPresenter.new(route_policy1).to_hash,
        Presenters::V3::RoutePolicyPresenter.new(route_policy2).to_hash
      )
    end

    it 'does not overwrite other included fields' do
      route_policy1 = RoutePolicy.create(route: route1, source_type: 'app', source_guid: 'app-guid-1')
      undecorated_hash = { foo: 'bar', included: { favorite_fruits: %w[tomato cucumber] } }
      hash = subject.decorate(undecorated_hash, [route1])
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:route_policies]).to contain_exactly(Presenters::V3::RoutePolicyPresenter.new(route_policy1).to_hash)
      expect(hash[:included][:favorite_fruits]).to match_array(%w[tomato cucumber])
    end

    it 'returns an empty array when routes have no policies' do
      hash = subject.decorate({}, [route1])
      expect(hash[:included][:route_policies]).to eq([])
    end

    it 'includes multiple policies for the same route' do
      policy_a = RoutePolicy.create(route: route1, source_type: 'app', source_guid: 'app-guid-a')
      policy_b = RoutePolicy.create(route: route1, source_type: 'app', source_guid: 'app-guid-b')
      hash = subject.decorate({}, [route1])
      expect(hash[:included][:route_policies]).to contain_exactly(
        Presenters::V3::RoutePolicyPresenter.new(policy_a).to_hash,
        Presenters::V3::RoutePolicyPresenter.new(policy_b).to_hash
      )
    end

    describe '.match?' do
      it 'matches include arrays containing "route_policies"' do
        expect(decorator.match?(%w[potato route_policies turnip])).to be(true)
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(%w[domain space])).not_to be(true)
      end
    end
  end
end
