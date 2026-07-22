require 'cloud_controller/errors/api_error'
require 'cloud_controller/errors/compound_error'

module VCAP::CloudController
  class AsyncOperationInProgress < StandardError; end

  class SubResourceError < StandardError
    attr_reader :errors

    def initialize(errors)
      super()
      @errors = errors
    end

    def underlying_errors
      @errors
    end

    def failures
      @errors.reject { |e| e.is_a?(AsyncOperationInProgress) }
    end

    def in_progress_operations
      @errors.select { |e| e.is_a?(AsyncOperationInProgress) }
    end

    def any_in_progress?
      in_progress_operations.any?
    end

    def message
      @errors.map(&:message).join("\n")
    end

    def self.raise_from(errors)
      return if errors.empty?

      raise new(errors)
    end
  end
end
