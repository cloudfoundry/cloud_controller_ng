require 'spec_helper'
require 'presenters/v3/route_policy_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      RSpec.describe RoutePolicyPresenter do
        let(:space)  { Space.make }
        let(:domain) { SharedDomain.make(name: 'apps.identity', enforce_route_policies: true) }
        let(:route)  { Route.make(space:, domain:) }
        let(:app_model) { AppModel.make(space:) }

        subject(:result) { RoutePolicyPresenter.new(route_policy).to_hash }

        describe '#to_hash relationships' do
          context 'when source is cf:app:<uuid>' do
            let(:route_policy) { RoutePolicy.create(source: "cf:app:#{app_model.guid}", route:) }

            it 'populates relationships.app and nulls space and organization' do
              expect(result[:relationships][:app]).to eq(data: { guid: app_model.guid })
              expect(result[:relationships][:space]).to eq(data: nil)
              expect(result[:relationships][:organization]).to eq(data: nil)
            end
          end

          context 'when source is cf:space:<uuid>' do
            let(:route_policy) { RoutePolicy.create(source: "cf:space:#{space.guid}", route:) }

            it 'populates relationships.space and nulls app and organization' do
              expect(result[:relationships][:app]).to eq(data: nil)
              expect(result[:relationships][:space]).to eq(data: { guid: space.guid })
              expect(result[:relationships][:organization]).to eq(data: nil)
            end
          end

          context 'when source is cf:org:<uuid>' do
            let(:route_policy) { RoutePolicy.create(source: "cf:org:#{space.organization.guid}", route:) }

            it 'populates relationships.organization and nulls app and space' do
              expect(result[:relationships][:app]).to eq(data: nil)
              expect(result[:relationships][:space]).to eq(data: nil)
              expect(result[:relationships][:organization]).to eq(data: { guid: space.organization.guid })
            end
          end

          context 'when source is cf:any' do
            let(:route_policy) { RoutePolicy.create(source: 'cf:any', route:) }

            it 'nulls all source relationships' do
              expect(result[:relationships][:app]).to eq(data: nil)
              expect(result[:relationships][:space]).to eq(data: nil)
              expect(result[:relationships][:organization]).to eq(data: nil)
            end
          end
        end

        describe '#to_hash source field' do
          context 'when source is cf:app' do
            let(:route_policy) { RoutePolicy.create(source: "cf:app:#{app_model.guid}", route:) }

            it 'emits the composite source string' do
              expect(result[:source]).to eq("cf:app:#{app_model.guid}")
            end
          end

          context 'when source is cf:any' do
            let(:route_policy) { RoutePolicy.create(source: 'cf:any', route:) }

            it 'emits cf:any' do
              expect(result[:source]).to eq('cf:any')
            end
          end
        end
      end
    end
  end
end
