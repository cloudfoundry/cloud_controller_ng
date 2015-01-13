require 'loggregator'

module VCAP::CloudController
  class MissingAppStartEvent < StandardError; end

  class AppStopEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_guid,
      :organization_name,
      :space_guid,
      :space_name,
      :app_guid,
      :app_name,
      :app_run_id,
    )

    def validate
      super
      validates_presence :space_guid
      validates_presence :space_name
      validates_presence :app_guid
      validates_presence :app_name
      validates_unique :app_run_id
    end

    def event_type
      'app_stop'
    end

    class << self
      def create_from_app(app)
        return unless app.space.organization.billing_enabled?
        app_start_event = AppStartEvent.filter(app_guid: app.guid).order(Sequel.desc(:id)).first

        unless app_start_event
          Loggregator.emit(app.guid, 'Tried to stop app that never received a start event')
          logger.warn('cc.app-stop-event.missing-start', app: app.guid)
          return
        end

        AppStopEvent.create(
          timestamp: Sequel::CURRENT_TIMESTAMP,
          organization_guid: app.space.organization_guid,
          organization_name: app.space.organization.name,
          space_guid: app.space.guid,
          space_name: app.space.name,
          app_guid: app.guid,
          app_name: app.name,
          app_run_id: app_start_event.app_run_id,
        )
      end

      private

      def logger
        @logger ||= Steno.logger('cc.models.app_stop_event')
      end
    end
  end
end
