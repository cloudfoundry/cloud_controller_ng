require "spec_helper"

module VCAP::CloudController
  describe FrontController do
    before :all do
      FrontController.get "/test_endpoint" do
        "test"
      end
    end

    describe "validating the auth token" do
      let(:user_id) { Sham.guid }
      let(:token_info) { {} }

      let(:config) do
        {
          :quota_definitions => [],
          :uaa => {:resource_id => "cloud_controller"}
        }
      end
      let(:token_decoder) do
        token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
        allow(token_decoder).to receive_messages(:decode_token => token_info)
        token_decoder
      end

      def app
        described_class.new(TestConfig.config, token_decoder)
      end

      def make_request
        get "/test_endpoint", "", {"HTTP_AUTHORIZATION" => "bearer token"}
      end

      context "when user_id is present" do
        before { token_info["user_id"] = user_id }

        it "creates a user" do
          expect {
            make_request
          }.to change { VCAP::CloudController::User.count }.by(1)

          user = VCAP::CloudController::User.last
          expect(user.guid).to eq(user_id)
          expect(user.active).to be true
        end

        it "sets security context to the user" do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to eq VCAP::CloudController::User.last
          expect(VCAP::CloudController::SecurityContext.token["user_id"]).to eq user_id
        end
      end

      context "when client_id is present" do
        before { token_info["client_id"] = user_id }

        it "creates a user" do
          expect {
            make_request
          }.to change { VCAP::CloudController::User.count }.by(1)

          user = VCAP::CloudController::User.last
          expect(user.guid).to eq(user_id)
          expect(user.active).to be true
        end

        it "sets security context to the user" do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to eq VCAP::CloudController::User.last
          expect(VCAP::CloudController::SecurityContext.token["client_id"]).to eq user_id
        end
      end

      context "when there is no user_id or client_id" do
        it "does not create user" do
          expect { make_request }.to_not change { VCAP::CloudController::User.count }
        end

        it "sets security context to be empty" do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
          expect(VCAP::CloudController::SecurityContext.token).to be_nil
        end
      end
    end
  end
end
