require "spec_helper"
require "rspec_api_documentation/dsl"

module VCAP::CloudController
  in_memory_db = Sequel.sqlite(':memory:')
  # db.logger = Logger.new($stdout) # <-- Uncomment to see SQL queries being made by Sequel
  in_memory_db.create_table :fakes do
    primary_key :id
    String :guid
    String :name
    Time :created_at
  end

  class FakeAccess < BaseAccess
  end

  class Fake < Sequel::Model(in_memory_db)
    attr_accessor :id, :created_at
    export_attributes :name
  end

  class FakesController < RestController::ModelController
    define_standard_routes
  end
end

resource "Common Functionality", :type => :api do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }

  authenticated_request

  describe "Enumeration" do
    get "/v2/fakes" do
      context "when there are no records" do
        example_request "Always includes metadata about pagination" do
          expect(status).to eq(200)
          expect(parsed_response).to eq({
                                            "total_results" => 0,
                                            "total_pages" => 1,
                                            "prev_url" => nil,
                                            "next_url" => nil,
                                            "resources" => []
                                        })
        end
      end

      context "when there are records" do
        around do |example|
          3.times { |i| VCAP::CloudController::Fake.create(name: "fake-#{i}") }

          example.run

          VCAP::CloudController::Fake.dataset.destroy
        end

        context "when order-direction" do
          context "is unspecified" do
            example_request "Enumerates in ascending order" do
              expect(status).to eq(200)

              fakes_that_came_back = parsed_response["resources"].map { |resource| resource["entity"]["name"] }
              expect(fakes_that_came_back).to eq(%w(fake-0 fake-1 fake-2))
            end
          end

          context "is specified" do
            example_request "enumerates in the specified order", "order-direction" => "desc" do
              expect(status).to eq(200)


              fakes_that_came_back = parsed_response["resources"].map { |resource| resource["entity"]["name"] }
              expect(fakes_that_came_back).to eq(%w(fake-2 fake-1 fake-0))
            end
          end
        end
      end
    end
  end
end
