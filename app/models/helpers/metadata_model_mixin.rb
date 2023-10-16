module VCAP::CloudController
  module MetadataModelMixin
    def self.included(included_class)
      included_class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # Transparently convert datatypes of key_prefix so empty strings are persisted in the DB instead of NULL
        def key_prefix
          self[:key_prefix].presence
        end
      RUBY
    end
  end
end
