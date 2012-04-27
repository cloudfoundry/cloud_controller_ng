# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "serialization" do |opts|
    let(:obj) { described_class.create(creation_opts) }

    it "should be seriazable to a hash and not include sensitive information" do
      hash = obj.to_hash
      hash.should be_a_kind_of(Hash)
      opts[:sensitive_attributes].each do |attr|
        hash.should_not include(attr.to_s)
        hash.should_not include(attr.to_sym)
      end
    end

    it "should be seriazable to json and not include sensitive information" do
      hash = obj.to_hash
      json = obj.to_json
      json.should be_a_kind_of(String)
      parsed_hash = Yajl::Parser.new.parse(json)
      parsed_hash.keys.should == hash.keys
    end
  end
end
