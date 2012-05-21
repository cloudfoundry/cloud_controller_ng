# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models; end

require "sequel_plugins/vcap_validations"
require "sequel_plugins/vcap_serialization"
require "sequel_plugins/vcap_normalization"
require "sequel_plugins/vcap_relations"
require "sequel_plugins/vcap_guid"

Sequel::Model.plugin :vcap_validations
Sequel::Model.plugin :vcap_serialization
Sequel::Model.plugin :vcap_normalization
Sequel::Model.plugin :vcap_relations
Sequel::Model.plugin :vcap_guid

module VCAP::CloudController::Models::UserGroup
  def define_user_group(name, opts = {})
    many_to_many(name,
                 :class =>"VCAP::CloudController::Models::User",
                 :join_table => "#{table_name}_#{name}",
                 :right_key => :user_id,
                 :reciprocol => opts[:reciprocol])

    add_association_dependencies name => :nullify
  end
end

Dir[File.expand_path("../models/*", __FILE__)].each do |file|
  require file
end
