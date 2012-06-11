# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::Domain do
  let(:domain) { Models::Domain.make }

  it_behaves_like "a CloudController model", {
    :required_attributes          => [:name, :organization],
    :unique_attributes            => :name,
    :stripped_string_attributes   => :name,
    :many_to_one => {
      :organization => lambda { |domain| VCAP::CloudController::Models::Organization.make }
    }
  }

  describe "conversions" do
    describe "name" do
      it "should downcase the name" do
        d = Models::Domain.create(:organization => domain.organization,
                                  :name => "ABC.COM")
        d.name.should == "abc.com"
      end
    end
  end

  describe "validations" do
    describe "name" do
      it "should accept a two level domain" do
        domain.name = "a.com"
        domain.should be_valid
      end

      it "should not allow a one level domain" do
        domain.name = "com"
        domain.should_not be_valid
      end

      it "should not allow a domain without a host" do
        domain.name = ".com"
        domain.should_not be_valid
      end

      it "should not allow a domain with a trailing dot" do
        domain.name = "a.com."
        domain.should_not be_valid
      end

      it "should not allow a three level domain TEMPORARY!" do
        domain.name = "a.b.com"
        domain.should_not be_valid
      end

      it "should perform case insensitive uniqueness" do
        d = Models::Domain.new(:organization => domain.organization,
                               :name => domain.name.upcase)
        d.should_not be_valid
      end
    end
  end
end
