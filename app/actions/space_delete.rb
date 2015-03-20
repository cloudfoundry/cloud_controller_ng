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
        errs = ServiceInstanceDelete.new.delete(space_model.service_instances_dataset)
        unless errs.empty?
          errors += errs
          return errors
        end

        AppDelete.new(user, user_email).delete(space_model.app_models_dataset)

        space_model.destroy
      end

      errors
    end

    def timeout_error(dataset)
      space_name = dataset.first.name
      VCAP::Errors::ApiError.new_from_details('SpaceDeleteTimeout', space_name)
    end

    private

    attr_reader :user_id, :user_email

    def user
      @user ||= User.find(id: @user_id)
    end
  end
end
