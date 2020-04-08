module VCAP::CloudController
  class ProcessDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(processes)
      processes = Array(processes)

      processes.each do |process|
        process.db.transaction do
          process.lock!
          Repositories::ProcessEventRepository.record_delete(process, @user_audit_info)
          process.destroy
        end
      end
    end
  end
end
