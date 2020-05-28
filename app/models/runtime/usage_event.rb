module VCAP::CloudController
  class UsageEvent < Sequel::Model(
    AppUsageEvent.select(
      Sequel.as('app', :type),
      :guid,
      :created_at,
      Sequel.as(:created_at, :updated_at)
    ).union(
      ServiceUsageEvent.select(
        Sequel.as('service', :type),
        :guid,
        :created_at,
        Sequel.as(:created_at, :updated_at)),
      all: true,
      from_self: false
    ).from_self
  )
  end
end
