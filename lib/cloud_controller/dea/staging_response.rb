module VCAP::CloudController::Dea
  class StagingResponse
    def initialize(response)
      @response = response
    end

    def log
      @response['task_log']
    end

    def streaming_log_url
      @response['task_streaming_log_url']
    end

    def detected_buildpack
      @response['detected_buildpack']
    end

    def execution_metadata
      @response['execution_metadata']
    end

    def detected_start_command
      @response['detected_start_command']
    end

    def procfile
      @response['procfile']
    end

    def droplet_hash
      @response['droplet_sha1']
    end

    def buildpack_key
      @response['buildpack_key']
    end

    def ==(other)
      response == other.response
    end

    protected

    attr_reader :response
  end
end
