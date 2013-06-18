require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe UserSummary do
    describe "GET /users/:guid/summary" do
      let(:org) { Models::Organization.make }
      let(:space) { Models::Space.make(organization: org) }
      let(:user) { make_user_for_space(space) }

      context "when the user exists" do
        subject { get("/v2/users/#{user.guid}/summary", {}, headers_for(user)) }

        context "and the user is authorized" do
          it "returns a 200 success" do
            subject
            expect(last_response.status).to eq 200
          end

          it "lists all the organizations the user belongs to" do
            subject
            expect(decoded_response(symbolize_keys: true)).to eq(::UserSummaryPresenter.new(user).to_hash)
          end
        end

        context "when the user is not authorized" do
          let(:user) { make_user }

          it "returns 403 Forbidden" do
            subject
            expect(last_response.status).to eq 403
          end
        end
      end

      context "when the user does not exist" do
        subject { get("/v2/users/9999/summary", {}, headers_for(user)) }

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
