# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::AppSecurityGroup, type: :model do
    it_behaves_like "a CloudController model", {
        required_attributes: [:name]
    }

    describe "validations" do
      context "name" do
        subject(:app_sec_group) { AppSecurityGroup.make }

        it "shoud allow standard ascii characters" do
          app_sec_group.name = "A -_- word 2!?()\'\"&+."
          expect {
            app_sec_group.save
          }.to_not raise_error
        end

        it "should allow backslash characters" do
          app_sec_group.name = "a\\word"
          expect {
            app_sec_group.save
          }.to_not raise_error
        end

        it "should allow unicode characters" do
          app_sec_group.name = "Ω∂∂ƒƒß√˜˙∆ß"
          expect {
            app_sec_group.save
          }.to_not raise_error
        end

        it "should not allow newline characters" do
          app_sec_group.name = "one\ntwo"
          expect {
            app_sec_group.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should not allow escape characters" do
          app_sec_group.name = "a\e word"
          expect {
            app_sec_group.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end
    end
  end
end