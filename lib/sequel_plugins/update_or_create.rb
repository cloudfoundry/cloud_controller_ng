module Sequel::Plugins::UpdateOrCreate
  module ClassMethods
    # Like +find_or_create+ but also updates the object in the case when it is in the DB
    def update_or_create(cond, &)
      obj = first(cond)
      if obj
        obj.tap(&).save(changed: true)
      else
        create(cond, &)
      end
    end
  end
end
