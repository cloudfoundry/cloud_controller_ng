require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyApiBase do
  let(:user) { Models::User.make(:admin => true, :active => true) }
  let(:logger) { VCAP::Logging.logger("vcap_spec") }
  let(:fake_req) { "" }

  describe "#default_app_space" do
    it "should raise NotAuthorized if the user is nil" do
      api = LegacyApiBase.new(nil, config, logger, fake_req)
      lambda { api.default_app_space }.should raise_error(Errors::NotAuthorized)
    end

    it "should raise LegacyApiWithoutDefaultAppSpace if the user has no app spaces" do
      api = LegacyApiBase.new(user, config, logger, fake_req)
      lambda {
        api.default_app_space
      }.should raise_error(Errors::LegacyApiWithoutDefaultAppSpace)
    end

    context "with app spaces" do
      let(:org) { Models::Organization.make }
      let(:as1) { Models::AppSpace.make(:organization => org) }
      let(:as2) { Models::AppSpace.make(:organization => org) }
      let(:api) { LegacyApiBase.new(user, config, logger, fake_req) }

      before do
        user.add_organization(org)
        user.add_app_space(as1)
        user.add_app_space(as2)
      end

      it "should return the first app space a user is in if default_app_space is not set" do
        api.default_app_space.should == as1
        user.remove_app_space(as1)
        api.default_app_space.should == as2
      end

      it "should return the explicitly set default app space if one is set" do
        user.default_app_space = as2
        api.default_app_space.should == as2
      end
    end
  end
end
