module VCAP::CloudController
  class AppDeleteFetcher
    def fetch(app_guid)
      dataset.where(:"#{AppModel.table_name}__guid" => app_guid)
    end

    private

    def dataset
      AppModel.dataset
    end
  end
end
