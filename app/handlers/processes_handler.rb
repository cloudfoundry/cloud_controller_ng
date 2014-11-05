module VCAP::CloudController
  class ProcessesHandler
    def initialize(process_repository, access_context)
      @process_repository = process_repository
      @access_context = access_context
    end

    def show(guid)
      handle do
        process = @process_repository.find_by_guid(guid)
        if process.nil? || @access_context.cannot?(:read, process)
          raise VCAP::Errors::ApiError.new_from_details('NotFound')
        end
        process
      end
    end

    def create(body)
      handle(body) do |opts|
        desired_process = @process_repository.new_process(opts)

        if @access_context.cannot?(:create, desired_process)
          raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
        end

        @process_repository.persist!(desired_process)
      end
    end

    def update(guid, body)
      handle(body) do |changes|
        @process_repository.find_by_guid_for_update(guid) do |initial_process|
          if initial_process.nil? || @access_context.cannot?(:update, initial_process)
            raise VCAP::Errors::ApiError.new_from_details('NotFound')
          end

          desired_process = @process_repository.update(initial_process, changes)

          if @access_context.cannot?(:update, desired_process)
            raise VCAP::Errors::ApiError.new_from_details('NotFound')
          end

          @process_repository.persist!(desired_process)
        end
      end
    end

    def delete(guid)
      handle do
        @process_repository.find_by_guid_for_update(guid) do |process|
          if process.nil? || @access_context.cannot?(:delete, process)
            raise VCAP::Errors::ApiError.new_from_details('NotFound')
          end

          @process_repository.delete(process)
        end
      end
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
