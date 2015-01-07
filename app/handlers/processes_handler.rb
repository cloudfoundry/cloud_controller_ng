require 'repositories/process_repository'

module VCAP::CloudController
  class ProcessCreateMessage
    attr_reader :opts
    attr_accessor :error

    def self.create_from_http_request(body)
      opts = body && MultiJson.load(body)
      raise MultiJson::ParseError.new('invalid request body') unless opts.is_a?(Hash)
      ProcessCreateMessage.new(opts)
    rescue MultiJson::ParseError => e
      message = ProcessCreateMessage.new(nil)
      message.error = e.message
      message
    end

    def valid?
      !@opts.nil?
    end

    private

    def initialize(opts)
      @opts = opts
    end
  end

  class ProcessUpdateMessage
    attr_reader :opts, :guid

    def self.create_from_http_request(guid, body)
      opts = body && MultiJson.load(body)
      opts = nil unless opts.is_a?(Hash)
      ProcessUpdateMessage.new(guid, opts)
    rescue MultiJson::ParseError
      nil
    end

    def validate
      errors = []
      errors << validate_name_field
      errors << validate_has_opts
      errors.compact
    end

    private

    def validate_name_field
      return 'The name field cannot be updated on a Process' if !@opts.nil? && @opts['name']
      nil
    end

    def validate_has_opts
      return 'Invalid Process' if @opts.nil?
      nil
    end

    def initialize(guid, opts)
      @opts = opts
      @guid = guid
    end
  end

  class ProcessesHandler
    class InvalidProcess < StandardError; end
    class Unauthorized < StandardError; end

    def initialize(process_repository, process_event_repository, paginator=SequelPaginator.new)
      @process_repository       = process_repository
      @process_event_repository = process_event_repository
      @paginator                = paginator
    end

    def list(pagination_options, access_context, filter_options={})
      dataset = nil
      if access_context.roles.admin?
        dataset = App.dataset
      else
        dataset = App.user_visible(access_context.user)
      end

      dataset = dataset.where(app_guid: filter_options[:app_guid]) if filter_options[:app_guid]

      @paginator.get_page(dataset, pagination_options)
    end

    def show(guid, access_context)
      process = @process_repository.find_by_guid(guid)
      if process.nil? || access_context.cannot?(:read, process)
        return nil
      end
      process
    end

    def create(create_message, access_context)
      guid = SecureRandom.uuid
      create_opts = create_message.opts.merge('guid' => guid)

      desired_process = @process_repository.new_process(create_opts)
      space           = Space.find(guid: desired_process.space_guid)

      raise Unauthorized if access_context.cannot?(:create, desired_process, space)

      process = @process_repository.create!(desired_process)

      user = access_context.user
      email = access_context.user_email

      @process_event_repository.record_app_create(process, space, user, email, create_message.opts)

      process
    rescue ProcessRepository::InvalidProcess => e
      raise InvalidProcess.new(e.message)
    end

    def update(update_message, access_context)
      @process_repository.find_for_update(update_message.guid) do |initial_process, initial_space, neighbor_processes|
        return if initial_process.nil?

        raise Unauthorized if access_context.cannot?(:update, initial_process, initial_space)

        desired_type = update_message.opts['type']
        neighbor_processes.each do |process|
          raise InvalidProcess.new("Type '#{desired_type}' is already in use") if process.type == desired_type
        end

        desired_process = initial_process.with_changes(update_message.opts)
        desired_space = update_message.opts['space_guid'] != initial_space.guid ? Space.find(guid: desired_process.space_guid) : initial_space

        raise Unauthorized if access_context.cannot?(:update, desired_process, desired_space)

        process = @process_repository.update!(desired_process)

        user = access_context.user
        email = access_context.user_email

        @process_event_repository.record_app_update(process, desired_space, user, email, update_message.opts)

        process
      end
    rescue ProcessRepository::InvalidProcess => e
      raise InvalidProcess.new(e.message)
    end

    def delete(guid, access_context)
      @process_repository.find_for_delete(guid) do |process, space|
        if process.nil? || access_context.cannot?(:delete, process, space)
          return nil
        end

        @process_repository.delete(process)

        user = access_context.user
        email = access_context.user_email

        @process_event_repository.record_app_delete_request(process, space, user, email, true)
        return process
      end
      nil
    end
  end
end
