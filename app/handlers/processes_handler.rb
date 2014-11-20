module VCAP::CloudController
  class ProcessCreateMessage
    attr_reader :opts
    attr_accessor :error

    def self.create_from_http_request(body)
      opts = body && MultiJson.load(body).symbolize_keys
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
    attr_accessor :error

    def self.create_from_http_request(guid, body)
      opts = body && MultiJson.load(body).symbolize_keys
      ProcessUpdateMessage.new(guid, opts)
    rescue MultiJson::ParseError => e
      message = ProcessUpdateMessage.new(guid, nil)
      message.error = e.message
      message
    end

    def valid?
      !@opts.nil?
    end

    private

    def initialize(guid, opts)
      @opts = opts
      @guid = guid
    end
  end


  class ProcessesHandler
    class InvalidProcess < StandardError; end
    class Unauthorized < StandardError; end

    def initialize(process_repository, process_event_repository)
      @process_repository = process_repository
      @process_event_repository = process_event_repository
    end

    def show(guid, access_context)
      process = @process_repository.find_by_guid(guid)
      if process.nil? || access_context.cannot?(:read, process)
        return nil
      end
      process
    end

    def create(create_message, access_context)
      desired_process = @process_repository.new_process(create_message.opts)
      space = Space.find(guid: desired_process.space_guid)

      raise Unauthorized if access_context.cannot?(:create, desired_process, space)

      process = @process_repository.persist!(desired_process)

      user = access_context.user
      email = access_context.user_email

      @process_event_repository.record_app_create(process, space, user, email, create_message.opts)

      process
    rescue ProcessRepository::InvalidProcess => e
      raise InvalidProcess.new(e.message)
    end

    def update(update_message, access_context)
      @process_repository.find_for_update(update_message.guid) do |initial_process, initial_space|
        return if initial_process.nil?

        raise Unauthorized if access_context.cannot?(:update, initial_process, initial_space)

        desired_process = initial_process.with_changes(update_message.opts)
        desired_space = update_message.opts[:space_guid] != initial_space.guid ? Space.find(guid: desired_process.space_guid) : initial_space

        raise Unauthorized if access_context.cannot?(:update, desired_process, desired_space)

        process = @process_repository.persist!(desired_process)

        user = access_context.user
        email = access_context.user_email

        @process_event_repository.record_app_update(process, desired_space, user, email, update_message.opts)

        process
      end
    rescue ProcessRepository::InvalidProcess => e
      raise InvalidProcess.new(e.message)
    end

    def delete(guid, access_context)
      @process_repository.find_for_update(guid) do |process, space|
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

    private

    def handle(body=nil)
      opts = body && MultiJson.load(body).symbolize_keys
      yield opts
    rescue ProcessRepository::InvalidProcess => e
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', e.message)
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    end
  end
end
