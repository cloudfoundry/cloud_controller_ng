require "spec_helper"

describe "Sequel::Plugins::VcapNormalization" do
  db = Sequel.sqlite(':memory:')
  db.create_table :foo_bars do
    primary_key :id

    String :val1
    String :val2
    String :val3
  end

  FooBar = Class.new(Sequel::Model) do
    plugin :vcap_normalization
    set_dataset(db[:foo_bars])
  end

  let(:model_object) { FooBar.new }

  describe ".strip_attributes" do
    it "should not cause anything to be normalized if not called" do
      model_object.val1 = "hi "
      model_object.val2 = " bye"
      model_object.val1.should == "hi "
      model_object.val2.should == " bye"
    end

    it "should only result in provided strings being normalized" do
      FooBar.strip_attributes :val2, :val3
      model_object.val1 = "hi "
      model_object.val2 = " bye"
      model_object.val3 = " with spaces "
      model_object.val1.should == "hi "
      model_object.val2.should == "bye"
      model_object.val3.should == "with spaces"
    end
  end
end
