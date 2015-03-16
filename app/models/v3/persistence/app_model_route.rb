module VCAP::CloudController
  class AppModelRoute < Sequel::Model(:apps_v3_routes)
    many_to_one :app, table_name: :apps_v3
    many_to_one :route
  end
end
