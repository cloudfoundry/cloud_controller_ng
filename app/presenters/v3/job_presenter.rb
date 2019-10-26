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

            links:      build_links,

            errors:     build_errors,
            warnings:   build_warnings,
          }
        end

        private

        def job
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
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
          # debugger
          warn("QQQ: job presenter: job.cf_api_error size: #{job.cf_api_error ? job.cf_api_error.size : 0}")
          djguid = job.delayed_job_guid
          djob = Delayed::Backend::Sequel::Job.find(guid: djguid)
          warn("QQQ delayed job.cf_api_error size: #{djob.cf_api_error ? djob.cf_api_error.size : 0}")

          return [] if job.cf_api_error.nil? || job.state == VCAP::CloudController::PollableJobModel::COMPLETE_STATE

          parsed_last_error = YAML.safe_load(job.cf_api_error)

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
