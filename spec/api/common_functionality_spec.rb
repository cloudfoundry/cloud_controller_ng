require "spec_helper"
require "rspec_api_documentation/dsl"

module VCAP::CloudController
  db = Sequel.sqlite(':memory:')
  db.create_table :fakes do
    primary_key :id
    String :guid
    String :name
    Time :created_at
  end

  class FakeAccess < BaseAccess
  end

  class Fake < Sequel::Model(db)
    attr_accessor :id, :created_at
    export_attributes :name
  end

  class FakesController < RestController::ModelController
    define_standard_routes
  end
end

resource "Common Functionality", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)['HTTP_AUTHORIZATION'] }

  authenticated_request

  describe "Pagination" do
    get "/v2/fakes" do
      it "always includes metadata about pagination" do
        client.get "/v2/fakes", {}, headers

        expect(status).to eq(200)
        expect(parsed_response).to eq({
                                          "total_results"=>0,
                                          "total_pages"=>0,
                                          "prev_url"=>nil,
                                          "next_url"=>nil,
                                          "resources"=>[]
                                      })
      end
    end
  end
end
