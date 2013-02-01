# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe "Sequel::Plugins::VcapNormalization" do
  before do
    reset_database

    db.create_table :test do
      primary_key :id

      String :val1
      String :val2
      String :val3
    end

    @c = Class.new(Sequel::Model)
    @c.plugin :vcap_normalization
    @c.set_dataset(db[:test])
    @m = @c.new
  end

  describe "#strip_attributes" do
    it "should not cause anything to be normalized if not called" do
      @m.val1 = "hi "
      @m.val2 = " bye"
      @m.val1.should == "hi "
      @m.val2.should == " bye"
    end

    it "should only result in provided strings being normalized" do
      @c.strip_attributes :val2, :val3
      @m.val1 = "hi "
      @m.val2 = " bye"
      @m.val3 = " with spaces "
      @m.val1.should == "hi "
      @m.val2.should == "bye"
      @m.val3.should == "with spaces"
    end
  end
end
