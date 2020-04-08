module VCAP::CloudController
  class StackDelete
    def delete(stack)
      stack.db.transaction do
        stack.destroy
      end
    end
  end
end
