# Copyright (c) 2009-2012 VMware, Inc.
require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::RestAPI::NamedAttribute do

    describe "#name" do
      it "should return the name provided" do
        attr = NamedAttribute.new("some_attr")
        attr.name.should == "some_attr"
      end
    end

    describe "#default" do
      it "should return nil if not provided" do
        attr = NamedAttribute.new("some_attr")
        attr.default.should be_nil
      end

      it "should return the default provided" do
        attr = NamedAttribute.new("some_attr", :default => "some default")
        attr.default.should == "some default"
      end
    end

    shared_examples "operation list" do |opt, meth, desc|
      describe "##{meth}" do
        it "should return false when called with a non-#{desc} operation" do
          attr = NamedAttribute.new("some_attr")
          attr.send(meth, :create).should be_false
        end

        it "should return true when called with an #{desc} operation" do
          attr = NamedAttribute.new("some_attr", opt => :read)
          attr.send(meth, :create).should be_false
          attr.send(meth, :read).should be_true
        end

        it "should work with a Symbol passed in via #{opt}" do
          attr = NamedAttribute.new("some_attr", opt => :read)
          attr.send(meth, :create).should be_false
          attr.send(meth, :read).should be_true
        end

        it "should work with an Array passed in via #{opt}" do
          attr = NamedAttribute.new("some_attr", opt => [:read, :update])
          attr.send(meth, :create).should be_false
          attr.send(meth, :read).should be_true
          attr.send(meth, :update).should be_true
        end
      end
    end

    include_examples "operation list", :exclude_in, :exclude_in?, "excluded"
    include_examples "operation list", :optional_in, :optional_in?, "optional"
  end
end
