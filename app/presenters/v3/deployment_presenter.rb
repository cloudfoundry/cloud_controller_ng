require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class DeploymentPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def to_hash
      {
        guid: deployment.guid,
        created_at: deployment.created_at,
        updated_at: deployment.updated_at,
        status: status(deployment),
        strategy: deployment.strategy,
        options: options(deployment),
        droplet: {
          guid: deployment.droplet_guid
        },
        previous_droplet: {
          guid: deployment.previous_droplet_guid
        },
        new_processes: new_processes,
        revision: revision,
        relationships: {
          app: {
            data: {
              guid: deployment.app_guid
            }
          }
        },
        metadata: {
          labels: hashified_labels(deployment.labels),
          annotations: hashified_annotations(deployment.annotations)
        },
        links: build_links
      }
    end

    private

    def deployment
      @resource
    end

    def revision
      deployment.app.revisions_enabled && deployment.revision_guid ? { guid: deployment.revision_guid, version: deployment.revision_version } : nil
    end

    def new_processes
      deployment.historical_related_processes.map do |drp|
        {
          guid: drp.process_guid,
          type: drp.process_type
        }
      end
    end

    def options(deployment)
      options = {
        max_in_flight: deployment.max_in_flight
      }
      options[:web_instances] = deployment.web_instances if deployment.web_instances
      options[:memory_in_mb] = deployment.memory_in_mb if deployment.memory_in_mb
      options[:disk_in_mb] = deployment.disk_in_mb if deployment.disk_in_mb
      options[:log_rate_limit_in_bytes_per_second] = deployment.log_rate_limit_in_bytes_per_second if deployment.log_rate_limit_in_bytes_per_second

      if deployment.strategy == VCAP::CloudController::DeploymentModel::CANARY_STRATEGY && deployment.canary_steps
        options[:canary] = {
          steps: deployment.canary_steps
        }
      end

      options
    end

    def status(deployment)
      status = {
        value: deployment.status_value,
        reason: deployment.status_reason,
        details: {
          last_successful_healthcheck: deployment.last_healthy_at,
          last_status_change: deployment.status_updated_at
        }
      }

      status[:details][:error] = deployment.error if deployment.error

      if deployment.strategy == VCAP::CloudController::DeploymentModel::CANARY_STRATEGY
        status[:canary] = {
          steps: {
            current: deployment.canary_current_step,
            total: deployment.canary_steps&.length || 1
          }
        }
      end

      status
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/deployments/#{deployment.guid}")
        },
        app: {
          href: url_builder.build_url(path: "/v3/apps/#{deployment.app_guid}")
        }
      }.tap do |links|
        if deployment.cancelable?
          links[:cancel] = {
            href: url_builder.build_url(path: "/v3/deployments/#{deployment.guid}/actions/cancel"),
            method: 'POST'
          }
        end
      end.tap do |links|
        if deployment.continuable?
          links[:continue] = {
            href: url_builder.build_url(path: "/v3/deployments/#{deployment.guid}/actions/continue"),
            method: 'POST'
          }
        end
      end
    end
  end
end
