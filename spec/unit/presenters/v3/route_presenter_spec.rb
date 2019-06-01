require 'spec_helper'
require 'presenters/v3/route_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RoutePresenter do
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

    describe '#to_hash' do
      subject do
        RoutePresenter.new(route).to_hash
      end

      let(:route) do
        VCAP::CloudController::Route.make(
          host: '',
          space: space,
          domain: domain
        )
      end

      let!(:route_label) do
        VCAP::CloudController::RouteLabelModel.make(
          resource_guid: route.guid,
          key_prefix: 'pfx.com',
          key_name: 'potato',
          value: 'baked'
        )
      end

      let!(:route_annotation) do
        VCAP::CloudController::RouteAnnotationModel.make(
          resource_guid: route.guid,
          key: 'contacts',
          value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)'
        )
      end

      it 'presents the route as json' do
        expect(subject[:guid]).to eq(route.guid)
        expect(subject[:created_at]).to be_a(Time)
        expect(subject[:updated_at]).to be_a(Time)
        expect(subject[:metadata][:labels]).to eq({ 'pfx.com/potato' => 'baked' })
        expect(subject[:metadata][:annotations]).to eq({ 'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)' })
        expect(subject[:relationships][:space][:data]).to eq({ guid: space.guid })
        expect(subject[:relationships][:domain][:data]).to eq({ guid: domain.guid })
        expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route.guid}")
        expect(subject[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{space.guid}")
        expect(subject[:links][:domain][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}")
      end
    end
  end
end
