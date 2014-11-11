require 'models/v3/mappers/process_mapper'

module VCAP::CloudController
  class AppRepository
    class MutationAttemptWithoutALock < StandardError; end
    class InvalidProcessAssociation < StandardError; end

    def new_app(opts)
      AppV3.new(opts)
    end

    def persist!(desired_app)
      attributes = attributes_for_app(desired_app).reject { |_, v| v.nil? }
      app_model = AppModel.create(attributes)

      app_from_model(app_model)
    end

    def find_by_guid(guid)
      app_model = AppModel.find(guid: guid)
      return if app_model.nil?
      app_from_model(app_model)
    end

    def find_by_guid_for_update(guid)
      app_model = AppModel.find(guid: guid)
      yield nil and return if app_model.nil?

      app_model.db.transaction do
        app_model.lock!
        app = app_from_model(app_model)
        @lock_acquired = true
        begin
          yield app
        ensure
          @lock_acquired = false
        end
      end
    end

    def remove_process!(app, process)
      raise InvalidProcessAssociation if process.nil? || !process.guid
      app_model = AppModel.find(guid: app.guid)
      app_model.remove_process_by_guid(process.guid)
    end

    def add_process!(app, process)
      raise InvalidProcessAssociation if process.nil? || !process.guid
      app_model = AppModel.find(guid: app.guid)
      app_model.add_process_by_guid(process.guid)
    end

    def delete(app)
      process_model = AppModel.find(guid: app.guid)
      return unless process_model
      raise MutationAttemptWithoutALock unless @lock_acquired
      process_model.destroy
    end

    def app_from_model(model)
      processes = App.where(app_guid: model.guid).eager(:space, :stack).all.map do |process|
        ProcessMapper.map_model_to_domain(process)
      end

      AppV3.new({
        guid: model.values[:guid],
        processes: processes,
        space_guid: model.values[:space_guid]
      })
    end

    private

    def attributes_for_app(app)
      {
        guid:                 app.guid,
        space_guid:           app.space_guid,
      }
    end
  end
end
