require 'spec_helper'
require 'presenters/v3/route_presenter'

module VCAP::CloudController
  describe RoutePresenter do
    describe '#present_json' do
      it 'presents the route as json' do
        route = Route.make

        json_result = RoutePresenter.new.present_json(route)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(route.guid)
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { double(:pagination_presenter) }
      let(:route1) { Route.make }
      let(:route2) { Route.make }
      let(:routes) { [route1, route2] }
      let(:presenter) { RoutePresenter.new(pagination_presenter) }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:options) { { page: page, per_page: per_page } }
      let(:paginated_result) { PaginatedResult.new(routes, total_results, PaginationOptions.new(options)) }
      before do
        allow(pagination_presenter).to receive(:present_pagination_hash) do |_, url|
          "pagination-#{url}"
        end
      end

      it 'presents the route as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, 'potato')
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |route_json| route_json['guid'] }
        expect(guids).to eq([route1.guid, route2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result, 'bazooka')
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination-bazooka')
      end
    end
  end
end
