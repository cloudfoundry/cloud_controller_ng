require "support/relation_types"

shared_examples "a CloudController model" do |opts|
  # the later code is simplified if we can assume that these are always
  # arrays
  relation_types = RelationTypes.all
  ([:sensitive_attributes, :extra_json_attributes] +
   relation_types).each do |k|
     opts[k] ||= []
     opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
   end

  include_examples "model relationships", opts
end
