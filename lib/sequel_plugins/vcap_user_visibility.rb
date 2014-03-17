module Sequel::Plugins::VcapUserVisibility
  module InstanceMethods
    def user_visible_relationship_dataset(name, user, admin_override = false)
      associated_model = self.class.association_reflection(name).associated_class
      relationship_dataset(name).filter(associated_model.user_visibility(user, admin_override))
    end
  end

  module ClassMethods
    # controller calls this to get the list of objects
    def user_visible(user, admin_override = false)
      dataset.filter(user_visibility(user, admin_override))
    end

    def user_visibility(user, admin_override)
      if admin_override
        full_dataset_filter
      elsif user
        user_visibility_filter(user)
      else
        {:id => nil}
      end
    end

    # this is overridden by models to determine which objects a user can see
    def user_visibility_filter(_)
      {:id => nil}
    end

    def full_dataset_filter
      {}
    end
  end
end