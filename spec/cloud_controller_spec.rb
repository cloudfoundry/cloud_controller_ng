require File.expand_path("../api/spec_helper", __FILE__)

describe VCAP::CloudController::Controller do
  let(:user_id) { Sham.guid }
  let(:fake_redis) { MockRedis.new }
  let(:config_key) { "some-key" }
  let(:uaa_url) { "uaa.some-domain.com" }
  let(:now) { Time.utc(2013, 2, 5) }
  let(:config_admin_email) { Sham.email }
  let(:symmetric_key) { nil }
  let!(:user) { VCAP::CloudController::Models::User.make(:admin => true, :guid => user_id) }

  before do
    Redis.stub(:new).and_return(fake_redis)

    Timecop.freeze(now)

    VCAP::CloudController::Controller.any_instance.stub(:config).and_return({
      :redis => {},
      :uaa => {
        :symmetric_secret => symmetric_key,
        :resource_id => "cloud_controller",
        :verification_key => config_key,
        :url => uaa_url,
      },
      :bootstrap_admin_email => config_admin_email
    })
  end

  describe "validating the auth token" do
    let(:headers) { {"HTTP_AUTHORIZATION" => auth_token} }
    let(:email) { Sham.email }
    let(:token_info) { {'user_id' => user_id, 'email' => email, 'scope' => ['cloud_controller.admin'] } }
    let(:valid_coder) do
      valid_coder = Object.new
      valid_coder.stub(:decode).with(auth_token).and_return(token_info)
      valid_coder
    end
    let(:invalid_coder) do
      valid_coder = Object.new
      valid_coder.stub(:decode).with(auth_token).and_raise(CF::UAA::InvalidSignature)
      valid_coder
    end

    subject { get "/hello/sync", {}, headers }

    context "when the token does not have the expected type (i.e. does not have the BEARER header)" do
      let(:auth_token) { "not-bearer some-token" }

      it "does not set the current user" do
        CF::UAA::TokenCoder.stub(:new).with(any_args).and_return(valid_coder)

        expect {
          subject
        }.not_to change {
          VCAP::CloudController::SecurityContext.current_user
        }
      end
    end

    context "when the token has the expected type" do
      let(:auth_token) { "bearer some-token" }

      context "when configured to use symmetric encryption" do
        let(:symmetric_key) { "some-symmetric-key" }

        it "uses the symmetric key from the config file to decode the auth token" do
          CF::UAA::TokenCoder.stub(:new).with(
            :audience_ids => "cloud_controller",
            :skey => symmetric_key,
          ).and_return(valid_coder)

          subject

          last_response.status.should == 200
          VCAP::CloudController::SecurityContext.current_user.should == user
          VCAP::CloudController::SecurityContext.token.should == token_info
        end
      end

      context "when configured to use asymmetric encryption" do
        let(:symmetric_key) { nil }

        context "when the UAA's public key is already cached in redis" do
          let(:cached_key) { "some-key-in-redis" }

          before { fake_redis['cc.verification_key'] = cached_key }

          it "uses that key to decode the auth token" do
            CF::UAA::TokenCoder.should_receive(:new).with(
              :audience_ids => "cloud_controller",
              :pkey => cached_key
            ).and_return(valid_coder)

            subject

            last_response.status.should == 200
            VCAP::CloudController::SecurityContext.current_user.should == user
            VCAP::CloudController::SecurityContext.token.should == token_info
          end
        end

        context "when the UAA's public key is provided in the config file" do
          it "uses that key to decode the auth token" do
            CF::UAA::TokenCoder.should_receive(:new).with(
              :audience_ids => "cloud_controller",
              :pkey => config_key
            ).and_return(valid_coder)

            subject

            last_response.status.should == 200
            VCAP::CloudController::SecurityContext.current_user.should == user
            VCAP::CloudController::SecurityContext.token.should == token_info
          end
        end

        context "when the public key stored in redis is no longer valid" do
          let(:old_key) { "some-old-key" }

          before do
            CF::UAA::TokenCoder.stub(:new).with(
              :audience_ids => "cloud_controller",
              :pkey => old_key
            ).and_return(invalid_coder)
            fake_redis['cc.verification_key'] = old_key
          end

          context "when the key was fetched from UAA recently (less than 10 mins ago)" do
            before do
              fake_redis['cc.verification_set_at'] = (now.to_i - 599)
              fake_redis['cc.verification_queried_at'] = (now.to_i - 21)
            end

            it "does not try to fetch the key again: the token is considered invalid" do
              subject

              expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
              expect(VCAP::CloudController::SecurityContext.token).to be_nil
            end

            it "logs that an invalid token was sent" do
              fake_logger = mock(:logger)
              fake_logger.should_receive(:warn).with(/key is too new/i)
              fake_logger.should_receive(:warn).with(/invalid bearer/i)
              VCAP::CloudController::Controller.any_instance.stub(:logger).and_return(fake_logger)
              subject
            end
          end

          context "when the key was requested from UAA recently (less than 20 seconds ago)" do
            before do
              fake_redis['cc.verification_set_at'] = (now.to_i - 601)
              fake_redis['cc.verification_queried_at'] = (now.to_i - 19)
            end

            it "does not try to fetch the key again: the request is still outstanding" do
              subject

              expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
              expect(VCAP::CloudController::SecurityContext.token).to be_nil
            end

            it "logs that an invalid token was sent" do
              fake_logger = mock(:logger)
              fake_logger.should_receive(:warn).with(/request was just made/i)
              fake_logger.should_receive(:warn).with(/invalid bearer/i)
              VCAP::CloudController::Controller.any_instance.stub(:logger).and_return(fake_logger)
              subject
            end
          end

          context "when the key has never been fetched from UAA" do
            let(:new_key) { "new-public-key-from-uaa" }
            let(:config_key) { nil }

            before do
              CF::UAA::Misc.stub(:validation_key).with(uaa_url).and_return(
                'value' => new_key
              )
              CF::UAA::TokenCoder.stub(:new).with(
                :audience_ids => "cloud_controller",
                :pkey => new_key
              ).and_return(valid_coder)
            end

            it "fetches the public key from UAA" do
              subject

              last_response.status.should == 200
              VCAP::CloudController::SecurityContext.current_user.should == user
              VCAP::CloudController::SecurityContext.token.should == token_info
            end

            it "updates the timestamp of the last fetch of the key in redis" do
              subject
              expect(fake_redis['cc.verification_queried_at']).to eq(now.to_i.to_s)
              expect(fake_redis['cc.verification_set_at']).to eq(now.to_i.to_s)
            end
          end

          context "when the key has not recently been fetched from UAA" do
            before do
              fake_redis['cc.verification_set_at'] = (now.to_i - 601)
              fake_redis['cc.verification_queried_at'] = (now.to_i - 21)
            end

            let(:new_key) { "new-public-key-from-uaa" }
            let(:config_key) { nil }

            before do
              CF::UAA::Misc.stub(:validation_key).with(uaa_url).and_return({
                'value' => new_key
              })
              CF::UAA::TokenCoder.stub(:new).with(
                :audience_ids => "cloud_controller",
                :pkey => new_key
              ).and_return(valid_coder)
            end

            it "fetches the public key from UAA" do
              subject

              last_response.status.should == 200
              VCAP::CloudController::SecurityContext.current_user.should == user
              VCAP::CloudController::SecurityContext.token.should == token_info
            end

            it "stores the public key in redis" do
              subject
              expect(fake_redis['cc.verification_key']).to eq(new_key)
            end

            context "when unable to fetch the key from UAA" do
              before do
                CF::UAA::Misc.stub(:validation_key).and_raise(CF::UAA::TargetError.new({'error' => 'other'}))
              end

              it "does not try to decode the token" do
                subject

                expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
                expect(VCAP::CloudController::SecurityContext.token).to be_nil
              end

              it "logs that an invalid token was sent" do
                fake_logger = mock(:logger)
                fake_logger.should_receive(:warn).with(/invalid bearer/i)
                VCAP::CloudController::Controller.any_instance.stub(:logger).and_return(fake_logger)
                subject
              end

              it "updates the timestamp of the last public key request from UAA in redis" do
                expect {
                  subject
                }.to change {
                  fake_redis['cc.verification_queried_at']
                }.to(now.to_i.to_s)
              end

              it "does not update the timestamp of the last public key response from UAA in redis" do
                  expect { subject }.not_to change { fake_redis['cc.verification_set_at'] }
                end
            end
          end
        end

        context "when the UAA's public key is not cached in redis and not in the config file" do
          context "when a request has just been sent to the UAA for the public key" do
            before do
              fake_redis['cc.verification_set_at'] = nil
              fake_redis['cc.verification_queried_at'] = (now.to_i - 19)
            end

            it "does not try to fetch the key again: the token is considered invalid" do
              subject

              expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
              expect(VCAP::CloudController::SecurityContext.token).to be_nil
            end
          end
        end

        context "when the users table is empty" do
          before do
            reset_database
            CF::UAA::TokenCoder.should_receive(:new).with(
              :audience_ids => "cloud_controller",
              :pkey => config_key
            ).and_return(valid_coder)
          end

          context "and the current user's email matches the admin email in the config file" do
            let(:token_info) { {'user_id' => user_id, 'email' => email, 'scope' => ['non_admin'] } }
            let(:email) { config_admin_email }

            it "saves the current user as an admin" do
              expect(VCAP::CloudController::Models::User.count).to eq(0)

              subject

              user = VCAP::CloudController::Models::User.first
              expect(user.guid).to eq(user_id)
              expect(user.admin).to be_true
              expect(user.active).to be_true
            end
          end

          context "and the current user is not admin" do
            let(:token_info) { {'user_id' => user_id, 'email' => email, 'scope' => ['non_admin'] } }

            it "does not create a user" do
              expect { subject }.not_to change(VCAP::CloudController::Models::User, :count)
            end
          end

          context "and the current user's token has an admin scope" do
            let(:token_info) { {'user_id' => user_id, 'email' => email, 'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] } }

            it "saves the current user as an admin" do
              expect(VCAP::CloudController::Models::User.count).to eq(0)

              subject

              user = VCAP::CloudController::Models::User.first
              expect(user.guid).to eq(user_id)
              expect(user.admin).to be_true
              expect(user.active).to be_true
            end
          end
        end
      end
    end
  end
end
