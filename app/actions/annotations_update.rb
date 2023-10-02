module VCAP::CloudController
  module AnnotationsUpdate
    class << self
      def update(resource, annotations, annotation_klass, destroy_nil: true)
        starting_annotation_count_for_resource = annotation_klass.where(resource_guid: resource.guid).count

        annotations ||= {}
        annotations.each do |key, value|
          key = key.to_s
          prefix, key_name = VCAP::CloudController::MetadataHelpers.extract_prefix(key)

          if value.nil? && destroy_nil # Delete Annotation
            annotation_klass.where(resource_guid: resource.guid, key_name: key_name).where(Sequel.or([[:key_prefix, prefix], [:key_prefix, prefix.to_s]])).try(:destroy)
            next
          end

          begin
            tries ||= 2
            annotation_klass.db.transaction(savepoint: true) do
              annotation = annotation_klass.where(resource_guid: resource.guid, key_name: key_name).where(Sequel.or([[:key_prefix, prefix], [:key_prefix, prefix.to_s]])).first
              annotation ||= annotation_klass.create(resource_guid: resource.guid, key_name: key_name.to_s, key_prefix: prefix.to_s)
              annotation.update(value:)
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
        return unless start_annotations_count < ending_annotations_count && ending_annotations_count > max_annotations_per_resource

        raise CloudController::Errors::ApiError.new_from_details('AnnotationLimitExceeded', annotations.size, max_annotations_per_resource)
      end

      def max_annotations_per_resource
        VCAP::CloudController::Config.config.get(:max_annotations_per_resource)
      end
    end
  end
end
