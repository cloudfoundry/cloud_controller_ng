require 'actions/service_instance_delete'

module VCAP::CloudController
  class SpaceDelete
    def initialize(user_id, user_email)
      @user_id = user_id
      @user_email = user_email
    end

    def delete(dataset)
      return [UserNotFoundDeletionError.new(@user_id)] if user.nil?

      errors = []
      dataset.each do |space_model|
        errs = ServiceInstanceDelete.new(space_model.service_instances_dataset).delete
        unless errs.empty?
          errors += errs
          return errors
        end

        AppDelete.new(space_model.app_models_dataset, user, user_email).delete

        space_model.destroy
      end

      errors
    end

    private

    attr_reader :user_id, :user_email

    def user
      @user ||= User.find(id: @user_id)
    end
  end
end
