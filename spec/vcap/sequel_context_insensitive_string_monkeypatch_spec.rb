# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "vcap/sequel_case_insensitive_string_monkeypatch"

describe "String :name" do
  context "with default options" do
    before do
      table_name = Sham.name.to_sym
      db.create_table table_name do
        primary_key :id
        String :str, :unique => true
      end

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
  end unless $spec_env.db.use_lower_where?

  context "with :context_insensitive => false" do
    before do
      table_name = Sham.name.to_sym

      db.create_table table_name do
        primary_key :id
        String :str, :unique => true, :case_insensitive => false
      end

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
  end unless $spec_env.db.use_lower_where?

  context "with :context_insensitive => true" do
    before do
      table_name = Sham.name.to_sym

      db.create_table table_name do
        String :str, :case_insensitive => true
        index :str, :unique => true, :case_insensitive => true
      end

      @c = Class.new(Sequel::Model) do
        ci_attributes :str
        def validate
          validates_unique_ci :str
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
    end unless $spec_env.db.use_lower_where?
  end

  context "alter table set_column_type" do
    before do
      @table_name = Sham.name.to_sym

      db.create_table @table_name do
        primary_key :id
        String :str, :unique => true
      end
    end

    context "with defaults" do
      it "should not result in a case sensitive column" do
        db.alter_table @table_name do
          set_column_type :str, String
        end

        @c = Class.new(Sequel::Model) do
        end
        @c.set_dataset(db[@table_name])
        @c.create(:str => "abc")
        @c.dataset[:str => "abc"].should_not be_nil
        @c.dataset[:str => "ABC"].should be_nil
      end
    end

    context "with :context_insensitive => false" do
      it "should not result in a case sensitive column" do
        db.alter_table @table_name do
          set_column_type :str, String
        end

        @c = Class.new(Sequel::Model) do
        end
        @c.set_dataset(db[@table_name])
        @c.create(:str => "abc")
        @c.dataset[:str => "abc"].should_not be_nil
        @c.dataset[:str => "ABC"].should be_nil
      end
    end

    context "with :context_insensitive => true" do
      it "should change the column" do
        db.alter_table @table_name do
          set_column_type :str, String, :case_insensitive => true
        end

        @c = Class.new(Sequel::Model) do
        end
        @c.set_dataset(db[@table_name])
        @c.create(:str => "abc")
        @c.dataset[:str => "abc"].should_not be_nil
        @c.dataset[:str => "ABC"].should_not be_nil
      end
    end
  end unless $spec_env.db.use_lower_where?
end
