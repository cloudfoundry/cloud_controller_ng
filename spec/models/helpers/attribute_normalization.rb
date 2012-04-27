# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "attribute normalization" do |opts|
    let(:obj) { described_class.make }

    opts[:stripped_string_attributes].each do |attr|
      describe "#{attr}" do
        it "should trim leading whitespace" do
          val          = obj.send(attr)
          new_val      = " #{val}_changed"
          expected_val = "#{val}_changed"

          obj.send("#{attr}=", new_val)
          obj.send(attr).should == expected_val
        end

        it "should trim trailing whitespace" do
          val          = obj.send(attr)
          new_val      = "#{val}_changed "
          expected_val = "#{val}_changed"

          obj.send("#{attr}=", new_val)
          obj.send(attr).should == expected_val
        end

        it "should trim leading and trailing whitespace" do
          val          = obj.send(attr)
          new_val      = "  #{val}_changed  "
          expected_val = "#{val}_changed"

          obj.send("#{attr}=", new_val)
          obj.send(attr).should == expected_val
        end
      end
    end
  end
end
