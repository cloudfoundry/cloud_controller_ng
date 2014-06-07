require "spec_helper"
require "vcap/sequel_case_insensitive_string_monkeypatch"

describe "String :name" do
  let(:table_name) { :unique_str_defaults }

  context "with default options" do
    before do
      @c = Class.new(Sequel::Model)
      @c.set_dataset(db[table_name])
      @c.create(:str => "abc")
    end

    it "should allow create with different case" do
      @c.create(:str => "ABC").should be_valid
    end

    it "should perform case sensitive search" do
      @c.dataset[:str => "abc"].should_not be_nil
      @c.dataset[:str => "aBC"].should be_nil
    end
  end

  context "with :case_insensitive => false" do
    let(:table_name) { :unique_str_case_sensitive }

    before do
      @c = Class.new(Sequel::Model)
      @c.set_dataset(db[table_name])
      @c.create(:str => "abc")
    end

    it "should allow create with different case" do
      @c.create(:str => "ABC").should be_valid
    end

    it "should perform case sensitive search" do
      @c.dataset[:str => "abc"].should_not be_nil
      @c.dataset[:str => "aBC"].should be_nil
    end
  end

  context "with :case_insensitive => true" do
    let(:table_name) { :unique_str_case_insensitive }

    before do
      @c = Class.new(Sequel::Model) do
        def validate
          validates_unique :str
        end
      end
      @c.set_dataset(db[table_name])
      @c.create(:str => "abc")
    end

    it "should not allow create with different case due to sequel validations" do
      expect {
        @c.create(:str => "ABC")
      }.to raise_error(Sequel::ValidationFailed)
    end

    it "should not allow create with different case due to db constraints" do
      expect {
        @c.new(:str => "ABC").save(:validate => false)
      }.to raise_error(Sequel::DatabaseError)
    end

    it "should perform case sensitive search" do
      @c.dataset[:str => "abc"].should_not be_nil
      @c.dataset[:str => "aBC"].should_not be_nil
    end
  end

  context "alter table set_column_type" do
    let(:table_name) { :unique_str_altered }

    context "with defaults" do
      it "should not result in a case sensitive column" do
        @c = Class.new(Sequel::Model)
        @c.set_dataset(db[table_name])
        @c.create(:altered_to_default => "abc")
        @c.dataset[:altered_to_default => "abc"].should_not be_nil
        @c.dataset[:altered_to_default => "ABC"].should be_nil
      end
    end

    context "with :case_insensitive => false" do
      it "should not result in a case sensitive column" do
        @c = Class.new(Sequel::Model)
        @c.set_dataset(db[table_name])
        @c.create(:altered_to_case_sensitive => "abc")
        @c.dataset[:altered_to_case_sensitive => "abc"].should_not be_nil
        @c.dataset[:altered_to_case_sensitive => "ABC"].should be_nil
      end
    end

    context "with :case_insensitive => true" do
      it "should change the column" do
        @c = Class.new(Sequel::Model)
        @c.set_dataset(db[table_name])
        @c.create(:altered_to_case_insensitive => "abc")
        @c.dataset[:altered_to_case_insensitive => "abc"].should_not be_nil
        @c.dataset[:altered_to_case_insensitive => "ABC"].should_not be_nil
      end
    end
  end
end
