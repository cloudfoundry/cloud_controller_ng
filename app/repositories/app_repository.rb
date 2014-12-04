require 'models/v3/mappers/process_mapper'

module VCAP::CloudController
  class AppRepository
    class MutationAttemptWithoutALock < StandardError; end
    class InvalidProcessAssociation < StandardError; end
    class AppNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def new_app(opts)
      AppV3.new(opts)
    end

    def create!(desired_app)
      attributes = attributes_for_app(desired_app).reject { |_, v| v.nil? }
      app_model = AppModel.create(attributes)

      app_from_model(app_model)
    end

    def update!(desired_app)
      raise MutationAttemptWithoutALock if !@lock_acquired

      app_model = AppModel.find(guid: desired_app.guid)
      raise AppNotFound if app_model.nil?

      app_model.name = desired_app.name if desired_app.name

      app_model.save

      app_from_model(app_model)
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
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

    def find_for_update(guid)
      AppModel.db.transaction do
        AppModel.for_update.where(guid: guid).first

        app_model = AppModel.where(guid: guid).
          eager_graph(:processes, :space => :organization).all.first

        yield nil and return if app_model.nil?

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
      raise MutationAttemptWithoutALock unless @lock_acquired
      app_model = AppModel.find(guid: app.guid)
      app_model.remove_process_by_guid(process.guid)
    end

    def add_process!(app, process)
      raise InvalidProcessAssociation if !process.guid
      raise MutationAttemptWithoutALock unless @lock_acquired
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
      processes = model.processes.map do |process|
        ProcessMapper.map_model_to_domain(process)
      end

      AppV3.new({
        guid:       model.values[:guid],
        name:       model.values[:name],
        processes:  processes,
        space_guid: model.values[:space_guid],
      })
    end

    private

    def attributes_for_app(app)
      {
        guid:       app.guid,
        name:       app.name,
        space_guid: app.space_guid,
      }
    end
  end
end
