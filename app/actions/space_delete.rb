require 'actions/service_instance_delete'

module VCAP::CloudController
  class SpaceDelete
    def self.for_space(space)
      new({ guid: space.guid }, SecurityContext.current_user, SecurityContext.current_user_email)
    end

    def self.for_organization(org)
      new({ organization_id: org.id }, SecurityContext.current_user, SecurityContext.current_user_email)
    end

    def initialize(dataset_opts, user, user_email)
      @dataset_opts = dataset_opts
      @user = user
      @user_email = user_email
    end

    def delete
      space_dataset = Space.where(dataset_opts)
      space_dataset.each do |space_model|
        AppDelete.new(space_model.app_models_dataset, user, user_email).delete
        ServiceInstanceDelete.new(space_model.service_instances_dataset).delete
      end

      space_dataset.destroy
    end

    private

    attr_reader :dataset_opts, :user, :user_email
  end
end
