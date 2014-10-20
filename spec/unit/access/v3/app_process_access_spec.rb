require 'spec_helper'

module VCAP::CloudController
  describe AppProcessAccess, type: :access do
    let(:token) { {} }
    let(:admin) { false }
    let(:user) { User.make }
    let(:roles) { double(:roles, admin?: admin) }
    let(:process) { ProcessFactory.make }
    let(:access_context) { double(:access_context, roles: roles, user: user) }

    before do
      SecurityContext.set(nil, token)
    end

    after do
      SecurityContext.clear
    end

    context "admin user" do
      let(:admin) { true }

      it "allows the user to read" do
        access_control = AppProcessAccess.new(access_context)
        expect(access_control.read?(nil)).to be_truthy
      end
    end

    context "non admin users" do
      context "when the user has sufficient scope and permission" do
        let(:token) {{ 'scope' => ['cloud_controller.read'] }}

        it "allows the user to read" do
          allow(ProcessModel).to receive(:user_visible).and_return(ProcessModel.where(guid: process.guid))
          access_control = AppProcessAccess.new(access_context)
          expect(access_control.read?(process)).to be_truthy
        end
      end

      context "when the user has insufficient scope" do
        it "disallows the user from reading" do
          allow(ProcessModel).to receive(:user_visible).and_return(ProcessModel.where(guid: process.guid))
          access_control = AppProcessAccess.new(access_context)
          expect(access_control.read?(process)).to be_falsey
        end
      end

      context "when the process is not visible to the user" do
        it "disallows the user from reading" do
          allow(ProcessModel).to receive(:user_visible).and_return(ProcessModel.where(guid: nil))
          access_control = AppProcessAccess.new(access_context)
          expect(access_control.read?(process)).to be_falsey
        end
      end
    end
  end
end
