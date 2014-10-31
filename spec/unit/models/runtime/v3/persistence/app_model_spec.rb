require 'spec_helper'

module VCAP::CloudController
  describe AppModel do
    let(:app_model) { AppModel.make }
    let(:space) { Space.find(guid: app_model.space_guid) }

    describe ".user_visible" do
      it "shows the developer apps" do
        developer = User.make
        space.organization.add_user developer
        space.add_developer developer
        expect(AppModel.user_visible(developer)).to include(app_model)
      end

      it "shows the space manager apps" do
        space_manager = User.make
        space.organization.add_user space_manager
        space.add_manager space_manager

        expect(AppModel.user_visible(space_manager)).to include(app_model)
      end

      it "shows the auditor apps" do
        auditor = User.make
        space.organization.add_user auditor
        space.add_auditor auditor

        expect(AppModel.user_visible(auditor)).to include(app_model)
      end

      it "shows the org manager apps" do
        org_manager = User.make
        space.organization.add_manager org_manager

        expect(AppModel.user_visible(org_manager)).to include(app_model)
      end

      it "hides everything from a regular user" do
        evil_hacker = User.make
        expect(AppModel.user_visible(evil_hacker)).to_not include(app_model)
      end
    end
  end
end
