module VCAP::CloudController
  class ProcessDelete
    def initialize(space, user, user_email)
      @space = space
      @user = user
      @user_email = user_email
    end

    def delete(processes)
      processes = [processes] unless processes.is_a?(Array)

      processes.each do |process|
        Repositories::Runtime::AppEventRepository.new.record_app_delete_request(process, space, user, user_email, true)
        process.destroy
      end
    end

    private

    attr_reader :space, :user, :user_email
  end
end
