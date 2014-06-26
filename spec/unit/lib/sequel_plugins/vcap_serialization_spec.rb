require "spec_helper"
require "securerandom"

describe "Sequel::Plugins::VcapSerialization" do
  before do
    in_memory_db = Sequel.sqlite(':memory:')
    in_memory_db.create_table :test do
      primary_key :id

      Integer :val1
      Integer :val2
      Integer :val3
    end

    @c = Class.new(Sequel::Model)
    @c.plugin :vcap_serialization
    @c.set_dataset(in_memory_db[:test])
  end

  describe "#create_from_hash" do
    it "should succeed when setting only allowed values" do
      @c.import_attributes :val1, :val2, :val3
      m = @c.create_from_hash :val1 => 1, :val2 => 2, :val3 => 3
      expect(m.val1).to eq(1)
      expect(m.val2).to eq(2)
      expect(m.val3).to eq(3)
    end

    it "should not set attributes not marked for import" do
      @c.import_attributes :val1, :val3
      m = @c.create_from_hash :val1 => 1, :val2 => 2, :val3 => 3
      expect(m.val1).to eq(1)
      expect(m.val2).to eq(nil)
      expect(m.val3).to eq(3)
    end
  end

  describe "#create_from_json" do
    it "should succeed when setting only allowed values" do
      @c.import_attributes :val1, :val2, :val3
      json = Yajl::Encoder.encode :val1 => 1, :val2 => 2, :val3 => 3
      m = @c.create_from_json json
      expect(m.val1).to eq(1)
      expect(m.val2).to eq(2)
      expect(m.val3).to eq(3)
    end

    it "should not set attributes not marked for import" do
      @c.import_attributes :val1, :val3
      json = Yajl::Encoder.encode :val1 => 1, :val2 => 2, :val3 => 3
      m = @c.create_from_json json
      expect(m.val1).to eq(1)
      expect(m.val2).to eq(nil)
      expect(m.val3).to eq(3)
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
      expect(@r.val1).to eq(101)
      expect(@r.val2).to eq(102)
      expect(@r.val3).to eq(103)
    end

    it "should not set attributes not marked for import" do
      @c.import_attributes :val1, :val3
      json = Yajl::Encoder.encode :val1 => 101, :val2 => 102, :val3 => 103
      @r.update_from_json json
      expect(@r.val1).to eq(101)
      expect(@r.val2).to eq(10)
      expect(@r.val3).to eq(103)
    end
  end
end
