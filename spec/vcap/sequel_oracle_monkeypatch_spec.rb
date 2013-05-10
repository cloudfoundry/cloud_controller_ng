# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "vcap/sequel_case_insensitive_string_monkeypatch"

#Should work for all databases but we're specifically testing Oracle here.
describe "Oracle Boolean Monkey Patch" do
  context "with 'boolean' column" do
    before do
      table_name = Sham.name.to_sym
      db.create_table table_name do
        String    :key
        TrueClass :bool
      end

      @c = Class.new(Sequel::Model)
      @c.set_dataset(db[table_name])
      @c.create(:key => "true", :bool => true)
      @c.create(:key => "false", :bool => false)
    end

    it "should be able to query true" do
      @c.dataset[:bool => true].key.should eql "true"
    end

    it "should be able to query false" do
      @c.dataset[:bool => false].key.should eql "false"
    end

    it "should return TrueClass" do
      result = @c.dataset[:bool => true]
      result.bool.should eql true
      result.bool.should be_an_instance_of TrueClass
    end

    it "should return FalseClass" do
      result = @c.dataset[:bool => false]
      result.bool.should eql false
      result.bool.should be_an_instance_of FalseClass
    end
  end
end
