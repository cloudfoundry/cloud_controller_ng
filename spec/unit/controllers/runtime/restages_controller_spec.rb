require "spec_helper"

module VCAP::CloudController
  describe RestagesController, type: :controller do
    describe "POST /v2/apps/:id/restage" do
      let(:package_state) { "STAGED" }
      let!(:application) { AppFactory.make(:package_hash => "abc", :package_state => package_state) }

      subject(:restage_request) { post("/v2/apps/#{application.guid}/restage", {}, headers_for(account)) }

      context "as a user" do
        let(:account) { make_user_for_space(application.space) }

        it "should return 403" do
          restage_request
          expect(last_response.status).to eq(403)
        end
      end

      context "as a developer" do
        let(:account) { make_developer_for_space(application.space) }

        it "returns a success response" do
          restage_request
          expect(last_response.status).to eq(201)
        end

        it "restages the app" do
          allow_any_instance_of(VCAP::CloudController::RestagesController).to receive(:find_guid_and_validate_access).with(:read, application.guid).and_return(application)

          allow(application).to receive(:restage!)
          restage_request

          expect(application).to have_received(:restage!)
        end

        it "returns the application" do
          restage_request
          expect(last_response.body).to match("v2/apps")
          expect(last_response.body).to match(application.guid)
        end

        context "when the app is pending to be staged" do
          before do
            application.package_state = "PENDING"
            application.save
          end

          it "returns '170002 NotStaged'" do
            restage_request

            expect(last_response.status).to eq(400)
            parsed_response = Yajl::Parser.parse(last_response.body)
            expect(parsed_response["code"]).to eq(170002)
          end
        end
      end
    end
  end
end
