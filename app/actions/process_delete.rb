module VCAP::CloudController
  class ProcessDelete
    def delete(processes)
      processes = [processes] unless processes.is_a?(Array)

      processes.each(&:destroy)
    end
  end
end
