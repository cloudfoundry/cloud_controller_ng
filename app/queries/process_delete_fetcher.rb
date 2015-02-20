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

      ds.association_join(:space).
        where(space__guid: @user.spaces_dataset.association_join(:organization).
              where(organization__status: 'active').select(:space__guid)).
        select_all(App.table_name)
    end
  end
end
