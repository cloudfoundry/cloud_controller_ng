module VCAP::CloudController
  class ProcessDeleteFetcher
    def initialize(user)
      @user = user
    end

    def fetch(process_guid)
      process_dataset = dataset.where(:"#{App.table_name}__guid" => process_guid)
      return nil if process_dataset.empty?

      space = Space.select_all(Space.table_name).unordered.
        join(AppModel.table_name, space_guid: :"#{Space.table_name}__guid").
        join(App.table_name, app_guid: :"#{AppModel.table_name}__guid").
        where(:"#{App.table_name}__guid" => process_guid).first

      [process_dataset, space]
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
