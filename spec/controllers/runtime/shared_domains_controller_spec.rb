require "spec_helper"

module VCAP::CloudController
  describe SharedDomainsController, type: :controller do
    describe "POST /v2/shared_domains" do
      context "when a name is given" do
        it "returns 201 Created" do
          post "/v2/shared_domains",
               '{"name":"example.com"}',
               json_headers(admin_headers)

          last_response.status.should == 201
        end

        it "creates the shared domain" do
          expect {
            post "/v2/shared_domains",
                 '{"name":"example.com"}',
                 json_headers(admin_headers)

            response = Yajl::Parser.parse(last_response.body)
            guid = response["metadata"]["guid"]

            shared_domain = SharedDomain.find(:guid => guid)
            expect(shared_domain.name).to eq("example.com")
          }.to change {
            SharedDomain.count
          }.by(1)
        end
      end

      context "when a name is NOT given" do
        it "returns a 400-level error code" do
          post "/v2/shared_domains",
               '{}',
               json_headers(admin_headers)

          last_response.status.should == 400
        end
      end
    end

    describe "GET /v2/shared_domains" do
      before do
        @shared_domain_a = SharedDomain.make
        @shared_domain_b = SharedDomain.make
      end

      context "when the request is not authenticated" do
        it "returns a 401 status code" do
          get "/v2/shared_domains", {}, {}
          expect(last_response.status).to eq(401)
        end
      end

      it "lists all of the shared domains" do
        get "/v2/shared_domains", {}, admin_headers

        parsed_body = Yajl::Parser.parse(last_response.body)
        parsed_body["total_results"].should == 2
      end

      describe "filtering by name" do
        let(:domain) { SharedDomain.make }

        it "should return the domain with the matching name" do
          get "/v2/shared_domains?q=name:#{domain.name}", {}, admin_headers
          last_response.status.should == 200
          decoded_response["resources"].size.should == 1
          decoded_response["resources"][0]["entity"]["name"].should == domain.name
        end
      end


      describe "GET /v2/shared_domains/:guid" do
        context "when the guid is valid" do
          it "returns the correct shared domain" do
            get "/v2/shared_domains/#{@shared_domain_a.guid}", {}, admin_headers

            last_response.status.should == 200

            parsed_body = Yajl::Parser.parse(last_response.body)
            expect(parsed_body["entity"]["name"]).to eq(@shared_domain_a.name)
          end
        end

        context "when the guid is invalid" do
          it "returns a 404 error" do
            get "/v2/shared_domains/some-bogus-guid", {}, admin_headers

            last_response.status.should == 404
          end
        end
      end
    end

    describe "DELETE /v2/shared_domains/:guid" do
      let(:shared_domain) { SharedDomain.make }

      it "returns status code 204" do
        delete "/v2/shared_domains/#{shared_domain.guid}", {}, admin_headers

        last_response.status.should == 204
      end

      it "deletes the shared domain" do
        expect {
          delete "/v2/shared_domains/#{shared_domain.guid}", {}, admin_headers
        }.to change {
          SharedDomain.find(:guid => shared_domain.guid)
        }.to(nil)
      end

      context "when there are routes using the domain" do
        let!(:route) { Route.make(domain: shared_domain) }

        it "should dot delete the route" do
          expect {
            delete "/v2/shared_domains/#{shared_domain.guid}", {}, admin_headers
          }.to_not change {
            SharedDomain.find(guid: shared_domain.guid)
          }
        end

        it "should return an error" do
          delete "/v2/shared_domains/#{shared_domain.guid}", {}, admin_headers
          expect(last_response.status).to eq(400)
          expect(decoded_response["code"]).to equal(10006)
          expect(decoded_response["description"]).to match /delete the routes associations for your domains/i
        end
      end
    end

    describe "PUT /v2/shared_domains/:guid" do
      let(:domain) { SharedDomain.make }

      context "and a name is given" do
        it "returns 201 Created" do
          expect {
            put "/v2/shared_domains/#{domain.guid}",
                 '{"name":"example.com"}',
                 json_headers(admin_headers)
          }.to change { domain.reload.name }.to("example.com")

          last_response.status.should == 201
        end
      end
    end
  end
end
