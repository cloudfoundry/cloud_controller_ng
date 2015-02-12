require 'models/v3/mappers/process_mapper'

module VCAP::CloudController
  class ProcessRepository
    class MutationAttemptWithoutALock < StandardError; end
    class InvalidProcess < StandardError; end
    class ProcessNotFound < StandardError; end

    def new_process(opts)
      AppProcess.new(opts)
    end

    def update!(desired_process)
      raise MutationAttemptWithoutALock if !@lock_acquired

      original = App.find(guid: desired_process.guid)
      process_model = ProcessMapper.map_domain_to_existing_model(desired_process, original)

      raise ProcessNotFound if process_model.nil?

      process_model.save
      ProcessMapper.map_model_to_domain(process_model)
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end

    def create!(desired_process)
      process_model = ProcessMapper.map_domain_to_new_model(desired_process)

      process_model.save
      ProcessMapper.map_model_to_domain(process_model)
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end

    def find_by_guid(guid)
      process_model = App.where(guid: guid).first
      return if process_model.nil?
      ProcessMapper.map_model_to_domain(process_model)
    end

    def find_for_show(guid)
      process_model = App.where(apps__guid: guid).eager_graph(:space).all.first
      return nil, nil if process_model.nil?
      [ProcessMapper.map_model_to_domain(process_model), process_model.space]
    end

    def find_for_update(guid)
      App.db.transaction do
        # We need to lock the row in the apps table. However we cannot eager
        # load associations while using the for_update method. Therefore we
        # need to fetch the App twice. This allows us to only make 2 queries,
        # rather than 3-4.
        App.for_update.where(guid: guid).first
        process_model = App.where(apps__guid: guid).
          eager_graph(:stack, space: :organization).all.first

        return if process_model.nil? && yield(nil, nil, [])

        neighboring_processes = []
        if process_model.app
          process_model.app.processes.each do |p|
            neighboring_processes << ProcessMapper.map_model_to_domain(p) if p.guid != process_model.guid
          end
        end

        @lock_acquired = true
        begin
          yield ProcessMapper.map_model_to_domain(process_model), process_model.space, neighboring_processes
        ensure
          @lock_acquired = false
        end
      end
    end

    def find_for_delete(filter: {})
      App.db.transaction do
        # We need to lock the row in the apps table. However we cannot eager
        # load associations while using the for_update method. Therefore we
        # need to fetch the App twice. This allows us to only make 2 queries,
        # rather than 3-4.
        dataset = App.for_update
        allowed_filters = %i(app_guid guid)
        return [] if (filter.keys - allowed_filters).size > 0

        filter.each do |column, value|
          dataset = dataset.where(:"#{App.table_name}__#{column}" => value)
        end

        dataset = App
        filter.each do |column, value|
          dataset = dataset.where(:"#{App.table_name}__#{column}" => value)
        end

        processes = dataset.eager_graph(:stack, space: :organization).all

        return if processes.empty? && yield(nil, nil)

        @lock_acquired = true
        begin
          processes.each do |process_model|
            yield ProcessMapper.map_model_to_domain(process_model), process_model.space
          end
        ensure
          @lock_acquired = false
        end
      end
    end

    def delete(process)
      process_model = App.find(guid: process.guid)
      return unless process_model
      raise MutationAttemptWithoutALock unless @lock_acquired
      process_model.destroy

      process
    end
  end
end
