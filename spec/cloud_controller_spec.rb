require "spec_helper"

describe VCAP::CloudController::Controller do
  describe "validating the auth token", type: :controller do
    let(:email) { Sham.email }
    let(:user_id) { Sham.guid }
    let(:token_info) { {} }

    let(:config) do
      {
          :quota_definitions => [],
          :uaa => { :resource_id => "cloud_controller" }
      }
    end
    let(:token_decoder) do
      token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
      token_decoder.stub(:decode_token => token_info)
      token_decoder
    end

    def app
      described_class.new(config, token_decoder)
    end

    def make_request
      get "/hello/sync", {}, {"HTTP_AUTHORIZATION" => "bearer token"}
    end

    def self.it_creates_and_sets_admin_user
      it "creates admin user" do
        expect {
          make_request
        }.to change { user_count }.by(1)

        VCAP::CloudController::User.last.tap do |u|
          expect(u.guid).to eq(user_id)
          expect(u.admin).to be_true
          expect(u.active).to be_true
        end
      end

      it "sets user to created admin user" do
        make_request
        expect(VCAP::CloudController::SecurityContext.current_user).to eq(
          VCAP::CloudController::User.order(:id).last
        )
      end
    end

    def self.it_creates_and_sets_non_admin_user
      it "creates non-admin user" do
        expect {
          make_request
        }.to change { user_count }.by(1)

        VCAP::CloudController::User.order(:id).last.tap do |u|
          expect(u.guid).to eq(user_id)
          expect(u.admin).to be_false
          expect(u.active).to be_true
        end
      end

      it "sets user to created non-admin user" do
        make_request
        expect(VCAP::CloudController::SecurityContext.current_user).to eq(
          VCAP::CloudController::User.order(:id).last
        )
      end
    end

    def self.it_does_not_create_user
      it "does not create user" do
        expect { make_request }.to_not change { user_count }
      end
    end

    def self.it_sets_found_user
      context "when user can be found" do
        before { VCAP::CloudController::User.make(:guid => user_id) }

        it "sets user to found user" do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user.guid).to eq(user_id)
        end
      end

      context "when user cannot be found" do
        it "sets user to found user" do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
        end
      end
    end

    def self.it_recognizes_admin_users
      context "when scope includes cc admin scope" do
        let(:expected_token_info) { token_info }

        before do
          VCAP::CloudController::User.make
          token_info["scope"] = [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE]
        end

        it_creates_and_sets_admin_user

        it "sets token info" do
          make_request
          expect(VCAP::CloudController::SecurityContext.token).to eq expected_token_info
        end
      end
    end

    context "when user_id is present" do
      before { token_info["user_id"] = user_id }
      it_recognizes_admin_users
    end

    context "when client_id is present" do
      before { token_info["client_id"] = user_id }
      it_recognizes_admin_users
    end

    context "when there is no user_id or client_id" do
      let(:expected_token_info) { nil }

      it_does_not_create_user

      it "sets current user to be nil because user cannot be found" do
        make_request
        expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
      end

      it "sets token info" do
        make_request
        expect(VCAP::CloudController::SecurityContext.token).to eq expected_token_info
      end
    end

    def user_count
      VCAP::CloudController::User.count
    end
  end
end
