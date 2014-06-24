require "support/relation_types"

shared_examples "a CloudController model" do |opts|
  # the later code is simplified if we can assume that these are always
  # arrays
  relation_types = RelationTypes.all
  ([:unique_attributes, :stripped_string_attributes,
   :sensitive_attributes, :extra_json_attributes, :disable_examples] +
   relation_types).each do |k|
     opts[k] ||= []
     opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
   end

  include_examples "model instance", opts
  include_examples "model relationships", opts
  include_examples "model enumeration", opts
end
