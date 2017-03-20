module VCAP::RestAPI
  class AppQuery < Query
    def filtered_dataset
      filter_args_from_query.inject(@ds) do |filter, cond|
        if cond.is_a?(Hash)
          if cond.key?(:organization)
            org_filter(filter, cond)
          elsif cond.key?(:stack)
            stack_filter(filter, cond)
          elsif cond.key?(:name)
            name_filter(filter, cond)
          else
            filter.filter(cond)
          end
        else
          filter.filter(cond)
        end
      end
    end

    def org_filter(ds, cond)
      ds.where(space: VCAP::CloudController::Space.where(organization: cond[:organization]))
    end

    def stack_filter(ds, cond)
      stack_names = cond[:stack].select(:name)

      ds.where(
        app: VCAP::CloudController::AppModel.where(
          buildpack_lifecycle_data: VCAP::CloudController::BuildpackLifecycleDataModel.where(stack: stack_names).
            exclude(app_guid: nil).
            select(:guid)
        ).select(:guid)
      )
    end

    def name_filter(ds, cond)
      ds.where(app: VCAP::CloudController::AppModel.filter(cond))
    end

    def raise_if_column_is_missing(query_key, column)
      return if [:stack_guid, :name].include?(query_key)

      raise CloudController::Errors::ApiError.new_from_details('BadQueryParameter', query_key) unless column
    end

    def column_type(query_key)
      return 'text' if query_key == :name
      column = model.db_schema[query_key.to_sym]
      raise_if_column_is_missing(query_key, column)
      column[:type]
    end
  end
end
