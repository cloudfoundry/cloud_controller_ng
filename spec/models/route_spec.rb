# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::Route do
  it_behaves_like "a CloudController model", {
    :required_attributes  => [:host, :domain],
    :unique_attributes    => [:host, :domain],
    :stripped_string_attributes => :host,
    :many_to_one => {
      :domain => lambda { |route| VCAP::CloudController::Models::Domain.make }
    }
  }

  describe "conversions" do
    describe "host" do
      it "should downcase the host" do
        d = Models::Route.make(:host => "ABC")
        d.host.should == "abc"
      end
    end
  end

  describe "validations" do
    let(:route) { Models::Route.make }

    describe "host" do
      it "should not allow . in the host name" do
        route.host = "a.b"
        route.should_not be_valid
      end

      it "should not allow / in the host name" do
        route.host = "a/b"
        route.should_not be_valid
      end
    end
  end

  describe "#fqdn" do
    it "should return the fqdn of for the route" do
      d = Models::Domain.make(:name => "foobar.com")
      r = Models::Route.make(:host => "www", :domain => d)
      r.fqdn.should == "www.foobar.com"
    end
  end

end
