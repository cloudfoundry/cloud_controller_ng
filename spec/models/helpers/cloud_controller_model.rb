# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  def self.relation_types
    relations = []
    ["one", "many"].each do |cardinality_left|
      ["zero_or_more", "zero_or_one",
       "one", "one_or_more"].each do |cardinality_right|
         relations << "#{cardinality_left}_to_#{cardinality_right}".to_sym
       end
    end
    relations
  end

  shared_examples "a CloudController model" do |opts|
    # the later code is simplified if we can assume that these are always
    # arrays
    relation_types = VCAP::CloudController::ModelSpecHelper.relation_types
    ([:required_attributes, :unique_attributes, :stripped_string_attributes,
     :sensitive_attributes, :extra_json_attributes, :disable_examples] +
     relation_types).each do |k|
       opts[k] ||= []
       opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
     end

     ["instance", "relationships", "enumeration"].each do |examples|
       describe examples do
         include_examples "model #{examples}", opts
       end
     end
  end
end
