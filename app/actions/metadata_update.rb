require 'actions/labels_update'
require 'actions/annotations_update'

module VCAP::CloudController
  class MetadataUpdate
    class << self
      def update(resource, message, destroy_nil: true)
        return unless message.requested?(:metadata)

        LabelsUpdate.update(resource, message.labels, labels_klass(resource), destroy_nil: destroy_nil)
        AnnotationsUpdate.update(resource, message.annotations, annotations_klass(resource), destroy_nil: destroy_nil)
      end

      private

      def labels_klass(resource)
        resource.class.association_reflections[:labels].associated_class
      end

      def annotations_klass(resource)
        resource.class.association_reflections[:annotations].associated_class
      end
    end
  end
end
