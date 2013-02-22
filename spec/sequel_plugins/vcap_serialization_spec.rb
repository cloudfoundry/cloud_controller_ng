# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe "Sequel::Plugins::VcapSerialization" do
  let(:model) { Class.new(Sequel::Model) }

  before do
    reset_database

    db.create_table :test do
      primary_key :id

      Integer :val1
      Integer :val2
      Integer :val3
      Integer :nested_val1
      Integer :nested_val2
    end

    model.plugin :vcap_serialization
    model.set_dataset(db[:test])
  end

  describe "#default_order_by" do
    before do
      model.export_attributes :val1, :val2, :val3
      @r1 = model.create :val1 => 2, :val2 => 20
      @r2 = model.create :val1 => 1, :val2 => 10
    end

    it "should set a default order by" do
      model.default_order_by(:val1)
      model.to_json.should == Yajl::Encoder.encode(
        [ {:val1 => 1, :val2 => 10, :val3 => nil},
          {:val1 => 2, :val2 => 20, :val3 => nil} ])
    end

    it "should use :id as the default if not specified" do
      model.to_json.should == Yajl::Encoder.encode(
        [ {:val1 => 2, :val2 => 20, :val3 => nil},
          {:val1 => 1, :val2 => 10, :val3 => nil} ])
    end
  end

  describe "#create_from_hash" do
    it "should succeed when setting only allowed values" do
      model.import_attributes :val1, :val2, :val3
      m = model.create_from_hash :val1 => 1, :val2 => 2, :val3 => 3
      m.val1.should == 1
      m.val2.should == 2
      m.val3.should == 3
    end

    it "should not set attributes not marked for import" do
      model.import_attributes :val1, :val3
      m = model.create_from_hash :val1 => 1, :val2 => 2, :val3 => 3
      m.val1.should == 1
      m.val2.should == nil
      m.val3.should == 3
    end
  end

  describe "#create_from_json" do
    it "should succeed when setting only allowed values" do
      model.import_attributes :val1, :val2, :val3
      json = Yajl::Encoder.encode :val1 => 1, :val2 => 2, :val3 => 3
      m = model.create_from_json json
      m.val1.should == 1
      m.val2.should == 2
      m.val3.should == 3
    end

    it "should not set attributes not marked for import" do
      model.import_attributes :val1, :val3
      json = Yajl::Encoder.encode :val1 => 1, :val2 => 2, :val3 => 3
      m = model.create_from_json json
      m.val1.should == 1
      m.val2.should == nil
      m.val3.should == 3
    end
  end

  describe "#to_json" do
    it "should only export attributes marked for export" do
      model.export_attributes :val2
      r = model.create :val1 => 1, :val2 => 10
      expected_json = Yajl::Encoder.encode :val2 => 10
      r.to_json.should == expected_json
    end

    context "when there are nested attributes" do
      before { model.export_attributes :nested_val1, :nested => [:val1, :val2] }

      it "copes with nested attributes" do
        r = model.create :nested_val1 => 10, :nested_val2 => 20
        r.to_json.should == Yajl::Encoder.encode(:nested_val1 => 10, :nested => {:val1 => 10, :val2 => 20})
      end
    end
  end

  describe "#update_from_json" do
    before do
      model.export_attributes :val2
      @r = model.create :val1 => 1, :val2 => 10
    end

    it "should succeed when setting only allowed values" do
      model.import_attributes :val1, :val2, :val3
      json = Yajl::Encoder.encode :val1 => 101, :val2 => 102, :val3 => 103
      @r.update_from_json json
      @r.val1.should == 101
      @r.val2.should == 102
      @r.val3.should == 103
    end

    it "should not set attributes not marked for import" do
      model.import_attributes :val1, :val3
      json = Yajl::Encoder.encode :val1 => 101, :val2 => 102, :val3 => 103
      @r.update_from_json json
      @r.val1.should == 101
      @r.val2.should == 10
      @r.val3.should == 103
    end
  end
end
