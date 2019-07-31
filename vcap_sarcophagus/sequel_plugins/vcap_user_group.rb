module Sequel::Plugins::VcapUserGroup
  module ClassMethods
    def define_user_group(name, opts={})
      opts = opts.merge(
        class: 'VCAP::CloudController::User',
        join_table: "#{table_name}_#{name}",
        right_key: :user_id
      )

      many_to_many(name, opts)
      add_association_dependencies name => :nullify
    end
  end
end
