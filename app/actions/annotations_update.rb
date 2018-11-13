module VCAP::CloudController
  module AnnotationsUpdate
    class << self
      def update(resource, annotations, annotation_klass)
        annotations ||= {}
        annotations.each do |key, value|
          key = key.to_s
          annotation = annotation_klass.find_or_create(resource_guid: resource.guid, key: key)
          annotation.update(value: value.to_s)
        end
      end
    end
  end
end
