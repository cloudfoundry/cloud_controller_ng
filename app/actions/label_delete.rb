module VCAP::CloudController
  class LabelDelete
    def self.delete(labels)
      labels.each(&:destroy)
    end
  end
end
