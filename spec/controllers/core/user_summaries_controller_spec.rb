require "spec_helper"

module VCAP::CloudController
  describe UserSummariesController, type: :controller do
    describe "GET /users/:guid/summary" do
      let(:org) { Models::Organization.make }
      let(:space) { Models::Space.make(organization: org) }
      let(:user) { make_user_for_space(space) }
      let(:current_user_headers) { admin_headers }

      context "when the user being summarized exists" do
        subject { get("/v2/users/#{user.guid}/summary", {}, current_user_headers) }

        context "and the current user is authorized" do
          it "returns a 200 success" do
            subject
            expect(last_response.status).to eq 200
          end

          it "lists all the organizations the user belongs to" do
            subject
            expect(decoded_response(symbolize_keys: true)).to eq(::UserSummaryPresenter.new(user).to_hash)
          end
        end

        context "when the current user is not authorized" do
          let(:current_user_headers) { headers_for(make_user) }

          it "returns 403 Forbidden" do
            subject
            expect(last_response.status).to eq 403
          end
        end
      end

      context "when the user being summarized does not exist" do
        subject { get("/v2/users/9999/summary", {}, current_user_headers) }

        it "returns 404 Not Found" do
          subject
          expect(last_response.status).to eq 404
        end
      end

      context "when the requester is not logged in" do
        subject { get("/v2/users/#{user.guid}/summary", {}, {}) }

        it "returns 401 Unauthorized" do
          subject
          expect(last_response.status).to eq 401
        end
      end
    end
  end
end
