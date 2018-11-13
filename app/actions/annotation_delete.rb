module VCAP::CloudController
  class AnnotationDelete
    def self.delete(annotations)
      annotations.each(&:destroy)
    end
  end
end
