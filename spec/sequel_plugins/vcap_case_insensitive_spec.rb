# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe "Sequel::Plugins::VcapCaseInsensitive" do
  context "with Test Model" do
    
    class Test < Sequel::Model
      ci_attributes :ci_str
      def validate
        validates_unique_ci :ci_str
        validates_unique_ci :ci_str, :int
        validates_unique_ci :str
      end
    end
    
    before do
      table_name = Sham.name.to_sym
      
      db.create_table table_name do
        String :ci_str, :case_insensitive => true
        String :str
        Integer :int
      end
  
      Test.set_dataset(db[table_name])
      Test.create :ci_str => "str_ci", :str => "str", :int => 1
    end
  
    describe "validate_unique_ci" do
     
      it "should fail case insensitive not unique" do
        test = Test.new(:ci_str => "Str_ci")
        test.should_not be_valid
      end
  
      it "should succeed case insensitive unique" do
        test = Test.new(:ci_str => "Str_ci2")
        test.should be_valid
      end
      
      it "should fail case sensitive not unique" do
        test = Test.new(:str => "str")
        test.should_not be_valid
      end
  
      it "should succeed case sensitive unique" do
        test = Test.new(:str => "Str")
        test.should be_valid
      end
  
      it "should fail dual type different case" do
        test = Test.new(:ci_str => "Str_ci", :int => 2)
        test.should_not be_valid
      end
  
      it "should succeed mixed type unique" do
        test = Test.new(:ci_str => "Str_ci2", :int => 2)
        test.should be_valid
      end
      
      it "should succeed nil" do
        test = Test.new(:ci_str => nil)
        test.should be_valid
      end
  
      it "should fail with where clause" do
        expect {
          Test.new(:ci_str => nil).validates_unique_ci :where => { }
        }.to raise_error(Sequel::Error, /:where/)
      end
    end
  end
end
