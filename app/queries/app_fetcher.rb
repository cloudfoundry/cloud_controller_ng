module VCAP::CloudController
  class AppFetcher
    def fetch(app_guid)
      dataset.where(:"#{AppModel.table_name}__guid" => app_guid).first
    end

    private

    def dataset
      AppModel.dataset.eager(:processes)
    end
  end
end
