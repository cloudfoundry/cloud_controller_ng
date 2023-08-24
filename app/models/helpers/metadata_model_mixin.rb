module VCAP::CloudController
  module MetadataModelMixin
    def self.included(included_class)
      included_class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # Transparently convert datatypes of key_prefix so empty strings are persisted in the DB instead of NULL
        def key_prefix
           self[:key_prefix].presence
         end
         def key_prefix=(value)
           self[:key_prefix] = value.nil? ? '' : value
         end
         def key_name=(val)
          self[:key_name] = val.nil? ? '' : val
        end
        def key_name
          self[:key_name].presence
        end

        # Initialize annotations with empty strings
        def initialize(*args)
          super
          self.key_prefix = '' if self.key_prefix.nil?
          self.key_name = '' if self.key_name.nil?
        end

      RUBY
    end
  end
end
