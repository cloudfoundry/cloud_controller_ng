module VCAP::CloudController
  class TaskListFetcher
    def fetch(pagination_options, space_guids, app_guid)
      dataset = TaskModel.select_all(:tasks)
      filter(pagination_options, dataset, space_guids, app_guid)
    end

    private

    def filter(pagination_options, dataset, space_guids, app_guid)
      if space_guids || app_guid
        dataset = dataset.join(AppModel.table_name, id: :app_id)
      end

      if space_guids
        dataset = dataset.where(:"#{AppModel.table_name}__space_guid" => space_guids)
      end

      if app_guid
        dataset = dataset.where(:"#{AppModel.table_name}__guid" => app_guid)
      end

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
