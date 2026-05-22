require 'spec_helper'
require 'decorators/include_binding_route_decorator'

module VCAP
  module CloudController
    RSpec.describe IncludeBindingRouteDecorator do
      subject(:decorator) { described_class }

      let(:bindings) do
        service_instance = create(:managed_service_instance, :routing)
        route = create(:route, space: service_instance.space, created_at: Time.now.utc - 1.second)

        [
          create(:route_binding, service_instance:, route:),
          create(:route_binding)
        ]
      end

      let(:routes) do
        bindings.map { |r| Presenters::V3::RoutePresenter.new(r.route).to_hash }
      end

      it 'decorates the given hash with service instances from bindings in the correct order' do
        dict = { foo: 'bar' }
        hash = subject.decorate(dict, bindings)
        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:routes]).to eq(routes)
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

        bindings << create(:route_binding, route: existing_route,
                                           service_instance: create(:managed_service_instance, :routing, space: existing_route.space))

        hash = subject.decorate({}, bindings)
        expect(hash[:included][:routes]).to have(2).items
      end

      describe '.match?' do
        it 'matches include arrays containing "route"' do
          expect(decorator.match?(%w[potato route turnip])).to be(true)
        end

        it 'does not match other include arrays' do
          expect(decorator.match?(%w[potato turnip])).not_to be(true)
        end
      end
    end
  end
end
