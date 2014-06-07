require "spec_helper"
require "securerandom"

describe "Sequel::Plugins::VcapSerialization" do
  before do
    db = Sequel.sqlite(':memory:')
    db.create_table :test do
      primary_key :id

      Integer :val1
      Integer :val2
      Integer :val3
    end

    @c = Class.new(Sequel::Model)
    @c.plugin :vcap_serialization
    @c.set_dataset(db[:test])
  end

  describe "#default_order_by" do
    before do
      @c.export_attributes :val1, :val2, :val3
      @r1 = @c.create :val1 => 2, :val2 => 20
      @r2 = @c.create :val1 => 1, :val2 => 10
    end

    it "should set a default order by" do
      @c.default_order_by(:val1)
      @c.to_json.should == Yajl::Encoder.encode(
        [ {:val1 => 1, :val2 => 10, :val3 => nil},
          {:val1 => 2, :val2 => 20, :val3 => nil} ])
    end

    it "should use :id as the default if not specified" do
      @c.to_json.should == Yajl::Encoder.encode(
        [ {:val1 => 2, :val2 => 20, :val3 => nil},
          {:val1 => 1, :val2 => 10, :val3 => nil} ])
    end
  end

  describe "#create_from_hash" do
    it "should succeed when setting only allowed values" do
      @c.import_attributes :val1, :val2, :val3
      m = @c.create_from_hash :val1 => 1, :val2 => 2, :val3 => 3
      m.val1.should == 1
      m.val2.should == 2
      m.val3.should == 3
    end

    it "should not set attributes not marked for import" do
      @c.import_attributes :val1, :val3
      m = @c.create_from_hash :val1 => 1, :val2 => 2, :val3 => 3
      m.val1.should == 1
      m.val2.should == nil
      m.val3.should == 3
    end
  end

  describe "#create_from_json" do
    it "should succeed when setting only allowed values" do
      @c.import_attributes :val1, :val2, :val3
      json = Yajl::Encoder.encode :val1 => 1, :val2 => 2, :val3 => 3
      m = @c.create_from_json json
      m.val1.should == 1
      m.val2.should == 2
      m.val3.should == 3
    end

    it "should not set attributes not marked for import" do
      @c.import_attributes :val1, :val3
      json = Yajl::Encoder.encode :val1 => 1, :val2 => 2, :val3 => 3
      m = @c.create_from_json json
      m.val1.should == 1
      m.val2.should == nil
      m.val3.should == 3
    end
  end

  describe "#to_json" do
    it "should only export attributes marked for export" do
      @c.export_attributes :val2
      r = @c.create :val1 => 1, :val2 => 10
      expected_json = Yajl::Encoder.encode :val2 => 10
      r.to_json.should == expected_json
    end

    it "should serialize Nil Objects to nil" do
      @c.export_attributes :val1, :val2
      r = @c.create :val1 => 1, :val2 => 123
      a_nil_object = double("A nil object", nil_object?: true)
      r.stub(:val2).and_return(a_nil_object)
      expected_json = Yajl::Encoder.encode :val1 => 1, :val2 => nil
      r.to_json.should == expected_json
    end

    it "should redact values marked for redaction" do
      @c.export_attributes :val1, :val2
      r = @c.create :val1 => 1, :val2 => 10
      expected_json = Yajl::Encoder.encode :val1 => { :redacted_message => '[PRIVATE DATA HIDDEN]' },:val2 => 10
      r.to_json({redact: ['val1']}).should == expected_json
    end

    it "should redact nil values marked for redaction" do
      @c.export_attributes :val1, :val2
      r = @c.create :val1 => nil, :val2 => 10
      expected_json = Yajl::Encoder.encode :val1 => { :redacted_message => '[PRIVATE DATA HIDDEN]' },:val2 => 10
      r.to_json({redact: ['val1']}).should == expected_json
    end
  end

  describe "#update_from_json" do
    before do
      @c.export_attributes :val2
      @r = @c.create :val1 => 1, :val2 => 10
    end

    it "should succeed when setting only allowed values" do
      @c.import_attributes :val1, :val2, :val3
      json = Yajl::Encoder.encode :val1 => 101, :val2 => 102, :val3 => 103
      @r.update_from_json json
      @r.val1.should == 101
      @r.val2.should == 102
      @r.val3.should == 103
    end

    it "should not set attributes not marked for import" do
      @c.import_attributes :val1, :val3
      json = Yajl::Encoder.encode :val1 => 101, :val2 => 102, :val3 => 103
      @r.update_from_json json
      @r.val1.should == 101
      @r.val2.should == 10
      @r.val3.should == 103
    end
  end
end
