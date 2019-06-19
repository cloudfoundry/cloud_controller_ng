module VCAP::CloudController
  class LabelSelectorRequirement
    attr_accessor :key, :key_name, :key_prefix, :operator, :values

    def initialize(key:, operator:, values:)
      @key = key
      @key_prefix, @key_name = VCAP::CloudController::MetadataHelpers.extract_prefix(key)
      @operator = operator
      @values = values.split(',')
    end
  end
end
