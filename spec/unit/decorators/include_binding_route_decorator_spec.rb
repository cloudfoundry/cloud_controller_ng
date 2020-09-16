require 'db_spec_helper'
require 'decorators/include_binding_route_decorator'

module VCAP
  module CloudController
    RSpec.describe IncludeBindingRouteDecorator do
      subject(:decorator) { described_class }
      let(:bindings) { Array.new(3) { RouteBinding.make } }
      let(:routes) {
        bindings.
          map(&:route).
          map { |r| Presenters::V3::RoutePresenter.new(r).to_hash }
      }

      it 'decorates the given hash with service instances from bindings' do
        dict = { foo: 'bar' }
        hash = subject.decorate(dict, bindings)
        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:routes]).to match_array(routes)
      end

      it 'does not overwrite other included fields' do
        dict = { foo: 'bar', included: { fruits: %w[tomato banana] } }
        hash = subject.decorate(dict, bindings)
        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:routes]).to match_array(routes)
        expect(hash[:included][:fruits]).to match_array(%w[tomato banana])
      end

      it 'does not include duplicates' do
        existing_route = bindings[0].route

        bindings << RouteBinding.make(
          route: existing_route,
          service_instance: ManagedServiceInstance.make(:routing, space: existing_route.space)
        )

        hash = subject.decorate({}, bindings)
        expect(hash[:included][:routes]).to have(3).items
      end

      describe '.match?' do
        it 'matches include arrays containing "route"' do
          expect(decorator.match?(%w[potato route turnip])).to be_truthy
        end

        it 'does not match other include arrays' do
          expect(decorator.match?(%w[potato turnip])).to be_falsey
        end
      end
    end
  end
end
