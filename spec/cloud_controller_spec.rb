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

    # TODO: Remove /hello/sync route from cloud_controller.rb,
    # and use something more appropriate here.
    def make_request
      get "/hello/sync", {}, {"HTTP_AUTHORIZATION" => "bearer token"}
    end

    def self.it_creates_and_sets_admin_user
      it "creates admin user" do
        expect {
          make_request
        }.to change { user_count }.by(1)

        VCAP::CloudController::User.order(:id).last.tap do |u|
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

    def self.it_sets_token_info
      it "sets token info" do
        make_request
        expect(VCAP::CloudController::SecurityContext.token).to eq token_info
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
      context "when email is present" do
        before { token_info["email"] = email }

        context "when email matches config's bootstrap_admin email" do
          before { config[:bootstrap_admin_email] = email }

          context "when there are 0 users in the ccdb" do
            before { reset_database }
            it_creates_and_sets_admin_user
            it_sets_token_info
          end

          context "when there are >0 users" do
            before { VCAP::CloudController::User.make }
            it_creates_and_sets_non_admin_user
            it_sets_token_info
          end
        end

        context "when email doesn't match config bootstrap_admin email" do
          before { config[:bootstrap_admin_email] = "some-other-bootstrap-email" }

          context "when there are 0 users in the ccdb" do
            before { reset_database }
            it_creates_and_sets_non_admin_user
            it_sets_token_info
          end

          context "when there are >0 users" do
            before { VCAP::CloudController::User.make }
            it_creates_and_sets_non_admin_user
            it_sets_token_info
          end
        end
      end

      context "when scope includes cc admin scope" do
        before { token_info["scope"] = [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] }
        it_creates_and_sets_admin_user
        it_sets_token_info
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
      it_does_not_create_user

      it "sets current user to be nil because user cannot be found" do
        make_request
        expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
      end

      it_sets_token_info
    end

    context "when the bearer token is invalid" do
      before do
        token_decoder.stub(:decode_token).and_raise(exception_class)
        Steno.stub(:logger).and_return(mock_logger)
      end
      let(:mock_logger) { double(:mock_logger) }

      %w[SignatureNotSupported SignatureNotAccepted InvalidSignature InvalidTokenFormat InvalidAudience].each do |exception|
        context "when the auth token raises #{exception}" do
          let(:exception_class) { "CF::UAA::#{exception}".constantize }
          it "should log to warn" do
            mock_logger.should_receive(:warn).with(/^Invalid bearer token: .+/)
            make_request
          end
        end
      end

      context "when the auth token raises TokenExpired" do
        let(:exception_class) { CF::UAA::TokenExpired }
        it "should log to info" do
          mock_logger.should_receive(:info).with(/^Token expired$/)
          make_request
        end
      end

      context "when an unknown exception is raised" do
        let(:exception_class) { RuntimeError }
        it 'should no rescue' do
          expect { make_request }.to raise_error(RuntimeError)
        end
      end
    end

    describe "#after" do
      it "closes ActiveRecord connection" do
        ActiveRecord::Base.connection.should_receive(:close)
        make_request
      end
    end

    def user_count
      VCAP::CloudController::User.count
    end
  end
end
