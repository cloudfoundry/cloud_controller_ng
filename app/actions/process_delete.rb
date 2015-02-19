module VCAP::CloudController
  class ProcessDelete
    def delete(process_dataset, space, user, user_email)
      select_columns = [:guid, :app_guid, :name]
      select_columns = select_columns.map do |column|
        :"#{App.table_name}__#{column}"
      end

      process_dataset.select(*select_columns).each do |process|
        Repositories::Runtime::AppEventRepository.new.record_app_delete_request(process, space, user, user_email, true)
      end
      process_dataset.destroy
    end
  end
end
