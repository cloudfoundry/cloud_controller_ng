# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :BillingEvent do
    serialization RestController::EntityOnlyObjectSerialization

    permissions_required do
      read Permissions::CFAdmin
    end

    # override base enumeration functionality.  This is mainly becase we need
    # better controll over the dataset returned, and we don't have generic
    # functionality for the controller to configure its dataset.
    def enumerate
      raise NotAuthenticated unless user

      unless start_time && end_time
        raise Errors::BillingEventQueryInvalid
      end

      ds = model.user_visible.filter(:event_timestamp => start_time..end_time)
      RestController::Paginator.render_json(self.class, ds, self.class.path,
                                            @opts.merge(:serialization => serialization))
    end

    private

    def start_time
      @start_time ||= parse_date_param("start_date")
    end

    def end_time
      @end_time ||= parse_date_param("end_date")
    end

    def parse_date_param(param)
      str = @params[param]
      Time.parse(str).localtime if str
    rescue
      raise Errors::BillingEventQueryInvalid
    end
  end
end
