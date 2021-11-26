module VCAP::CloudController::Presenters::Mixins
  module AssociationPresentationHelpers
    extend ActiveSupport::Concern

    class_methods do
      def merge_fields(fields, more_fields=nil)
        all_fields = Array.wrap(fields)
        all_fields += Array.wrap(more_fields) if more_fields
        all_fields.reduce { |f1, f2| _merge_fields(f1, f2) }
      end

      def associations(fields)
        Array.wrap(_associations(fields))
      end

      private

      def _merge_fields(fields_hash1, fields_hash2)
        fields_hash1.deep_merge(fields_hash2) do |_, value1, value2|
          fields, associations = _fields_and_associations(Array.wrap(value1) + Array.wrap(value2))
          [*fields.uniq, associations.reduce { |h1, h2| _merge_fields(h1, h2) }].compact
        end
      end

      def _associations(hash)
        associations = hash.map do |key, value|
          fields, associations = _fields_and_associations(value)
          proc_callback = fields.empty? || fields.include?(:*) ? nil : proc { |ds| ds.select(*fields) }
          cascaded_associations = associations.map { |h| _associations(h) }.reduce { |h1, h2| h1.deep_merge(h2) { raise 'duplicate key' } }

          if proc_callback && cascaded_associations
            { key => { proc_callback => cascaded_associations } }
          elsif proc_callback || cascaded_associations
            { key => proc_callback || cascaded_associations }
          else
            key
          end
        end
        associations.length > 1 ? associations : associations[0]
      end

      def _fields_and_associations(values)
        fields = []
        associations = []
        Array.wrap(values).each do |value|
          case value
          when Symbol
            fields << value
          when Hash
            associations << value
          when Array
            f, a = _fields_and_associations(v)
            fields += f
            associations += a
          else
            raise 'illegal type'
          end
        end
        [fields, associations]
      end
    end
  end
end
