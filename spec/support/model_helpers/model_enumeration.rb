# Copyright (c) 2009-2012 VMware, Inc.

module ModelHelpers
  shared_examples "model enumeration" do |opts|
    it "should return all the instances" do
      initial_count = described_class.count

      json = described_class.to_json
      hash = Yajl::Parser.new.parse(json)
      hash.length.should == initial_count

      5.times { described_class.make }
      json = described_class.to_json
      hash = Yajl::Parser.new.parse(json)
      hash.length.should == initial_count + 5
    end
  end
end
