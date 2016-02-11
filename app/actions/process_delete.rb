module VCAP::CloudController
  class ProcessDelete
    def delete(processes)
      processes = Array(processes)

      processes.each(&:destroy)
    end
  end
end
