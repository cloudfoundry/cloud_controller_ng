module VCAP::CloudController
  class StackDelete
    def delete(stack)
      stack.db.transaction do
        LabelDelete.delete(stack.labels)
        AnnotationDelete.delete(stack.annotations)
        stack.destroy
      end
    end
  end
end
