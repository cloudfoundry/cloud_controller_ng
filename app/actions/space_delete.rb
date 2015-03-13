require 'actions/service_instance_delete'

module VCAP::CloudController
  class SpaceDelete
    def initialize(user_id, user_email)
      @user_id = user_id
      @user_email = user_email
    end

    def delete(space_dataset)
      raise VCAP::Errors::ApiError.new_from_details('UserNotFound', user_id) if user.nil?

      space_dataset.each do |space_model|
        AppDelete.new(space_model.app_models_dataset, user, user_email).delete
        ServiceInstanceDelete.new(space_model.service_instances_dataset).delete
      end

      space_dataset.destroy
    end

    private

    attr_reader :user_id, :user_email

    def user
      @user ||= User.find(id: @user_id)
    end
  end
end
