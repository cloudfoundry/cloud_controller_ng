# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

shared_examples "a cf permission" do |name, granted, not_granted, nil_granted|
  nil_granted ||= false

  describe "#granted_to?" do
    it "should return true for a #{name} user" do
      described_class.granted_to?(granted).should be_true
    end

    it "should return false for non #{name} users" do
      described_class.granted_to?(not_granted).should be_false
    end

    it "should return #{nil_granted} for a nil user" do
      described_class.granted_to?(nil).should == nil_granted
    end
  end
end
