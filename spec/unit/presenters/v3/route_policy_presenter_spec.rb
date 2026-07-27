require 'spec_helper'
require 'presenters/v3/route_policy_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      RSpec.describe RoutePolicyPresenter do
        let(:space)  { create(:space) }
        let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true) }
        let(:route)  { create(:route, space:, domain:) }
        let(:app_model) { create(:app_model, space:) }

        subject(:result) { RoutePolicyPresenter.new(route_policy).to_hash }

        describe '#to_hash relationships' do
          context 'when source is cf:app:<uuid>' do
            let(:route_policy) { create(:route_policy, source: "cf:app:#{app_model.guid}", route: route) }

            it 'populates relationships.app and nulls space and organization' do
              expect(result[:relationships][:app]).to eq(data: { guid: app_model.guid })
              expect(result[:relationships][:space]).to eq(data: nil)
              expect(result[:relationships][:organization]).to eq(data: nil)
            end
          end

          context 'when source is cf:space:<uuid>' do
            let(:route_policy) { create(:route_policy, source: "cf:space:#{space.guid}", route: route) }

            it 'populates relationships.space and nulls app and organization' do
              expect(result[:relationships][:app]).to eq(data: nil)
              expect(result[:relationships][:space]).to eq(data: { guid: space.guid })
              expect(result[:relationships][:organization]).to eq(data: nil)
            end
          end

          context 'when source is cf:org:<uuid>' do
            let(:route_policy) { create(:route_policy, source: "cf:org:#{space.organization.guid}", route: route) }

            it 'populates relationships.organization and nulls app and space' do
              expect(result[:relationships][:app]).to eq(data: nil)
              expect(result[:relationships][:space]).to eq(data: nil)
              expect(result[:relationships][:organization]).to eq(data: { guid: space.organization.guid })
            end
          end

          context 'when source is cf:any' do
            let(:route_policy) { create(:route_policy, source: 'cf:any', route: route) }

            it 'nulls all source relationships' do
              expect(result[:relationships][:app]).to eq(data: nil)
              expect(result[:relationships][:space]).to eq(data: nil)
              expect(result[:relationships][:organization]).to eq(data: nil)
            end
          end
        end

        describe '#to_hash source field' do
          context 'when source is cf:app' do
            let(:route_policy) { create(:route_policy, source: "cf:app:#{app_model.guid}", route: route) }

            it 'emits the composite source string' do
              expect(result[:source]).to eq("cf:app:#{app_model.guid}")
            end
          end

          context 'when source is cf:any' do
            let(:route_policy) { create(:route_policy, source: 'cf:any', route: route) }

            it 'emits cf:any' do
              expect(result[:source]).to eq('cf:any')
            end
          end
        end

        describe '#to_hash links' do
          context 'when source is cf:app:<uuid>' do
            let(:route_policy) { create(:route_policy, source: "cf:app:#{app_model.guid}", route: route) }

            it 'includes an app link and omits space and organization links' do
              expect(result[:links][:app][:href]).to end_with("/v3/apps/#{app_model.guid}")
              expect(result[:links]).not_to have_key(:space)
              expect(result[:links]).not_to have_key(:organization)
            end
          end

          context 'when source is cf:space:<uuid>' do
            let(:route_policy) { create(:route_policy, source: "cf:space:#{space.guid}", route: route) }

            it 'includes a space link and omits app and organization links' do
              expect(result[:links][:space][:href]).to end_with("/v3/spaces/#{space.guid}")
              expect(result[:links]).not_to have_key(:app)
              expect(result[:links]).not_to have_key(:organization)
            end
          end

          context 'when source is cf:org:<uuid>' do
            let(:route_policy) { create(:route_policy, source: "cf:org:#{space.organization.guid}", route: route) }

            it 'includes an organization link and omits app and space links' do
              expect(result[:links][:organization][:href]).to end_with("/v3/organizations/#{space.organization.guid}")
              expect(result[:links]).not_to have_key(:app)
              expect(result[:links]).not_to have_key(:space)
            end
          end

          context 'when source is cf:any' do
            let(:route_policy) { create(:route_policy, source: 'cf:any', route: route) }

            it 'includes only self and route links' do
              expect(result[:links].keys).to contain_exactly(:self, :route)
            end
          end
        end
      end
    end
  end
end
