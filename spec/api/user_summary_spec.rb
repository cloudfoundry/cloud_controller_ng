require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::UserSummary do
  describe "GET /users/:guid/summary" do
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:space) { VCAP::CloudController::Models::Space.make(organization: org) }
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
          expect(decoded_response).to eq({
            'guid' => user.guid,
            'organizations' => [org.to_hash]
          })
        end

        it "lists all the managed organizations the user belongs to" do
        end

        it "lists all the billing managed organizations the user belongs to" do
        end
      end

      context "when the user is not authorized" do
        let(:user) { make_not_auth_user }

        xit "returns 403 Forbidden" do
          subject
          expect(last_response.status).to eq 403
        end

        it "returns an empty body" do

        end
      end
    end

    context "when the user does not exist" do
      subject { get("/v2/users/9999/summary", {}, headers_for(user)) }

      xit "returns 404 Not Found" do
        subject
        expect(last_response.status).to eq 404
      end

      it "returns an empty body" do

      end
    end

    context "when the requester is not logged in" do
      subject { get("/v2/users/#{user.guid}/summary", {}, {}) }

      xit "returns 401 Unauthorized" do
        subject
        expect(last_response.status).to eq 401
      end

      xit "returns an empty body" do

      end
    end
  end
end