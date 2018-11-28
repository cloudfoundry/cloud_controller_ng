module VCAP::CloudController
  module AnnotationsUpdate
    class TooManyAnnotations < StandardError; end

    class << self
      def update(resource, annotations, annotation_klass)
        annotations ||= {}
        starting_size = annotation_klass.where(resource_guid: resource.guid).count
        annotations.each do |key, value|
          key = key.to_s
          if value.nil?
            annotation_klass.find(resource_guid: resource.guid, key: key).try(:destroy)
            next
          end
          annotation = annotation_klass.find_or_create(resource_guid: resource.guid, key: key)
          annotation.update(value: value.to_s)
        end
        max_annotations = VCAP::CloudController::Config.config.get(:max_annotations_per_resource)
        current_size = resource.class.find(guid: resource.guid).annotations.size
        if starting_size < current_size && current_size > max_annotations
          raise TooManyAnnotations.new("Failed to add #{annotations.size} annotations because it would exceed maximum of #{max_annotations}")
        end
      end
    end
  end
end
