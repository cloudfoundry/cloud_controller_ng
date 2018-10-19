module VCAP::CloudController
  class LabelDelete
    def delete(labels)
      labels.each(&:destroy)
    end
  end
end
