require "spec_helper"

describe "Sequel::Plugins::VcapNormalization" do
  in_memory_db = Sequel.sqlite(':memory:')
  in_memory_db.create_table :foos do
    primary_key :id

    String :val
    String :val_stripped
  end

  in_memory_db.create_table :bars do
    primary_key :id

    String :val
  end

  class Foo < Sequel::Model(in_memory_db)
    plugin :vcap_normalization
    strip_attributes :val_stripped
  end

  class Bar < Sequel::Model(in_memory_db)
    plugin :vcap_normalization
  end

  describe ".strip_attributes" do
    it "should only result in provided strings being normalized" do
      model_object = Foo.new
      model_object.val = " hi "
      model_object.val_stripped = " bye "
      expect(model_object.val).to eq " hi "
      expect(model_object.val_stripped).to eq "bye"
    end

    it "should not cause anything to be normalized if not called" do
      model_object = Bar.new
      model_object.val = " hi "
      expect(model_object.val).to eq " hi "
    end
  end
end
