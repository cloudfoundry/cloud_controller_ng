# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::User do
  it_behaves_like "a CloudController model", {
    :required_attributes          => [:email, :crypted_password],
    :unique_attributes            => :email,
    :sensitive_attributes         => :crypted_password,
    :extra_json_attributes        => :password,
    :stripped_string_attributes   => :email,
    :many_to_zero_or_more => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :app_spaces    => lambda { |user|
        org = VCAP::CloudController::Models::Organization.make
        user.add_organization(org)
        VCAP::CloudController::Models::AppSpace.make(:organization => org)
      }
    }
  }

  describe "attribute normalization" do
    describe "email" do
      let(:user) { VCAP::CloudController::Models::User.make }

      context "bad addresses" do
        ["foo", "foo@bla@bla.com", "foo.bar.com"].each do |bad_email|
          it "should not allow an email address of '#{bad_email}'" do
            user.email = bad_email
            lambda {
              user.save
            }.should raise_error(Sequel::ValidationFailed, /email/)
          end
        end
      end

      it "should downcase email addresses" do
        user.email = "SomeEmail@SomeDomain.cOm"
        user.email.should == "someemail@somedomain.com"
      end

      it "should raise an error when saving a duplicate due to downcasing" do
        VCAP::CloudController::Models::User.make(:email => "abc@FOO.COM")
        lambda {
          VCAP::CloudController::Models::User.make(:email => "abc@foo.com")
        }.should raise_error(Sequel::ValidationFailed, /email unique/)
      end
    end
  end
end
