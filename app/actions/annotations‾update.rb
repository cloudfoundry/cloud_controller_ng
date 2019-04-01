module VCAP::CloudController
  module AnnotationsUpdate
    class << self
      def update(resource, annotations, annotation_klass)
        starting_annotation_count_for_resource = annotation_klass.where(resource_guid: resource.guid).count

        annotations ||= {}
        annotations.each do |key, value|
          key = key.to_s
          if value.nil?
            annotation_klass.find(resource_guid: resource.guid, key: key).try(:destroy)
            next
          end
          annotation = annotation_klass.find_or_create(resource_guid: resource.guid, key: key)
          annotation.update(value: value.to_s)
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
