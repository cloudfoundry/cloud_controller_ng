require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class JobPresenter < BasePresenter
        def to_hash
          {
            guid:       job.guid,
            created_at: job.created_at,
            updated_at: job.updated_at,

            operation:  job.operation,
            state:      job.state,

            errors:     build_errors,
            warnings:   build_warnings,

            links:      build_links,
          }
        end

        private

        def job
          @resource
        end

        def build_links
          links = {
            self: { href: url_builder.build_url(path: "/v3/jobs/#{job.guid}") }
          }

          if job.resource_exists?
            resource_type = job.resource_type.to_sym
            links[resource_type] = { href: url_builder.build_url(path: build_link_path) }
          end

          links
        end

        def build_link_path
          "/v3/#{ActiveSupport::Inflector.pluralize(job.resource_type)}/#{job.resource_guid}"
        end

        def build_errors
          return [] if job.cf_api_error.nil? || job.state == VCAP::CloudController::PollableJobModel::COMPLETE_STATE

          parsed_last_error = Psych.safe_load(job.cf_api_error, strict_integer: true)
          parsed_last_error['errors'].map(&:deep_symbolize_keys)
        end

        def build_warnings
          return [] if job.warnings.nil?

          job.warnings.map { |w| { detail: w[:detail] } }
        end
      end
    end
  end
end
