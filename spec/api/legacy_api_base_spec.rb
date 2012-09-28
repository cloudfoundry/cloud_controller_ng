require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::LegacyApiBase do
    let(:user) { Models::User.make(:admin => true, :active => true) }
    let(:logger) { Steno.logger("vcap_spec") }
    let(:fake_req) { "" }

    describe "#has_default_space" do
      it "should raise NotAuthorized if the user is nil" do
        SecurityContext.set(nil)
        api = LegacyApiBase.new(config, logger, {}, {}, fake_req)
        lambda { api.has_default_space? }.should raise_error(Errors::NotAuthorized)
      end

      context "with app spaces" do
        let(:org) { Models::Organization.make }
        let(:as) { Models::Space.make(:organization => org) }
        let(:api) {
          SecurityContext.set(user)
          LegacyApiBase.new(config, logger, {}, {}, fake_req)
        }

        before do
          user.add_organization(org)
        end

        it "should return true if the user is in atleast one app space and the default_space is not set" do
          user.add_space(as)
          api.has_default_space?.should == true
        end

        it "should return true if the default app space is set explicitly and the user is not in any app space" do
          user.default_space = as
          api.has_default_space?.should == true
        end

        it "should return false if the default app space is not set explicitly and the user is not in atleast one app space" do
          api.has_default_space?.should == false
        end
      end
    end

    describe "#default_space" do
      it "should raise NotAuthorized if the user is nil" do
        SecurityContext.set(nil)
        api = LegacyApiBase.new(config, logger, {}, {}, fake_req)
        lambda { api.default_space }.should raise_error(Errors::NotAuthorized)
      end

      it "should raise LegacyApiWithoutDefaultSpace if the user has no app spaces" do
        SecurityContext.set(user)
        api = LegacyApiBase.new(config, logger, {}, {}, fake_req)
        lambda {
          api.default_space
        }.should raise_error(Errors::LegacyApiWithoutDefaultSpace)
      end

      context "with app spaces" do
        let(:org) { Models::Organization.make }
        let(:as1) { Models::Space.make(:organization => org) }
        let(:as2) { Models::Space.make(:organization => org) }
        let(:api) {
          SecurityContext.set(user)
          LegacyApiBase.new(config, logger, {}, {}, fake_req)
        }

        before do
          user.add_organization(org)
          user.add_space(as1)
          user.add_space(as2)
        end

        it "should return the first app space a user is in if default_space is not set" do
          api.default_space.should == as1
          user.remove_space(as1)
          api.default_space.should == as2
        end

        it "should return the explicitly set default app space if one is set" do
          user.default_space = as2
          api.default_space.should == as2
        end
      end
    end
  end
end
