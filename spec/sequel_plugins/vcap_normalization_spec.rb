require "spec_helper"

describe "Sequel::Plugins::VcapNormalization" do
  before do
    db.create_table :test do
      primary_key :id

      String :val1
      String :val2
      String :val3
    end
  end

  after do
    db.drop_table :test
  end

  let!(:model_class) do
    Class.new(Sequel::Model) do
      plugin :vcap_normalization
      set_dataset(db[:test])
    end
  end

  let(:model_object) { model_class.new }

  describe ".strip_attributes" do
    it "should not cause anything to be normalized if not called" do
      model_object.val1 = "hi "
      model_object.val2 = " bye"
      model_object.val1.should == "hi "
      model_object.val2.should == " bye"
    end

    it "should only result in provided strings being normalized" do
      model_class.strip_attributes :val2, :val3
      model_object.val1 = "hi "
      model_object.val2 = " bye"
      model_object.val3 = " with spaces "
      model_object.val1.should == "hi "
      model_object.val2.should == "bye"
      model_object.val3.should == "with spaces"
    end
  end
end
