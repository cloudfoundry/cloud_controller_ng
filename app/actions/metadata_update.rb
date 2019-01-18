module VCAP::CloudController
  class MetadataUpdate
    class << self
      def update(resource, message)
        return unless message.requested?(:metadata)

        LabelsUpdate.update(resource, message.labels, labels_klass(resource))
        AnnotationsUpdate.update(resource, message.annotations, annotations_klass(resource))
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
