# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "serialization" do |opts|
    before(:all) do
      @obj = described_class.make
    end

    it "should be serializable to a hash and not include sensitive information" do
      hash = @obj.to_hash
      hash.should be_a_kind_of(Hash)

      opts[:sensitive_attributes].each do |attr|
        hash.should_not include(attr.to_s)
        hash.should_not include(attr.to_sym)
      end
    end

    it "should be serializable to json and not include sensitive information" do
      json = @obj.to_json
      json.should be_a_kind_of(String)

      parsed_hash = Yajl::Parser.new.parse(json)
      opts[:sensitive_attributes].each do |attr|
        parsed_hash.should_not include(attr.to_s)
        parsed_hash.should_not include(attr.to_sym)
      end
    end
  end
end
