# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "model enumeration" do |opts|
    it "should return an empty list when there are no instances" do
      json = described_class.to_json
      hash = Yajl::Parser.new.parse(json)
      hash.should be_empty
    end

    it "should return all the instances" do
      5.times { described_class.make }
      json = described_class.to_json
      hash = Yajl::Parser.new.parse(json)
      hash.length.should == 5
    end
  end
end
