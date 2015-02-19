module VCAP::CloudController
  class ProcessDeleteFetcher
    def initialize(user)
      @user = user
    end

    def fetch(process_guid)
      dataset.where(:"#{App.table_name}__guid" => process_guid).first
    end

    private

    def dataset
      ds = App.dataset
      return ds if @user.admin?

      ds.select_all(App.table_name).
        join(AppModel.table_name, guid: :app_guid).
        join(Space.table_name, guid: :space_guid).where(space_guid: @user.spaces_dataset.select(:guid)).
        join(Organization.table_name, id: :organization_id).where(status: 'active')
    end
  end
end
