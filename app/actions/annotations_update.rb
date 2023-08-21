module VCAP::CloudController
  module AnnotationsUpdate
    class << self
      def update(resource, annotations, annotation_klass, destroy_nil: true)
        starting_annotation_count_for_resource = annotation_klass.where(resource_guid: resource.guid).count

        annotations ||= {}
        annotations.each do |key, value|
          key = key.to_s
          prefix, key_name = VCAP::CloudController::MetadataHelpers.extract_prefix(key)

          # if the key has a prefix, but we can find its whole text in the key column,
          # it needs to be reformed in the newer, prefix-aware format.
          # see decisions/0004-adding-key-prefix-to-annotations.md.
          if prefix.present?
            annotation_klass.find(resource_guid: resource.guid, key: key)&.destroy
          end

          if value.nil? && destroy_nil # Delete Annotation
            annotation_klass.where(resource_guid: resource.guid, key: key_name).where(Sequel.or([[:key_prefix, prefix], [:key_prefix, prefix.to_s]])).try(:destroy)
            next
          end

          begin
            tries ||= 2
            annotation_klass.db.transaction(savepoint: true) do
              annotation = annotation_klass.where(resource_guid: resource.guid, key: key_name).where(Sequel.or([[:key_prefix, prefix], [:key_prefix, prefix.to_s]])).first
              annotation ||= annotation_klass.create(resource_guid: resource.guid, key: key_name.to_s, key_prefix: prefix.to_s)
              annotation.update(value: value)
            end
          rescue Sequel::UniqueConstraintViolation => e
            if (tries -= 1).positive?
              retry
            else
              v3_api_error!(:UniquenessError, e.message)
            end
          end
        end

        ending_annotation_count_for_resource = annotation_klass.where(resource_guid: resource.guid).count
        validate_max_annotations_limit!(annotations, starting_annotation_count_for_resource, ending_annotation_count_for_resource)
        annotations
      end

      private

      def validate_max_annotations_limit!(annotations, start_annotations_count, ending_annotations_count)
        if start_annotations_count < ending_annotations_count && ending_annotations_count > max_annotations_per_resource
          raise CloudController::Errors::ApiError.new_from_details('AnnotationLimitExceeded', annotations.size, max_annotations_per_resource)
        end
      end

      def max_annotations_per_resource
        VCAP::CloudController::Config.config.get(:max_annotations_per_resource)
      end
    end
  end
end
