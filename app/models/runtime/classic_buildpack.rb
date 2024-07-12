module VCAP::CloudController
  class ClassicBuildpack < Buildpack

    def self.list_admin_buildpacks(stack_name=nil)
      scoped = exclude(key: nil).exclude(key: '')
      if stack_name.present?
        scoped = scoped.filter(Sequel.or([
          [:stack, stack_name],
          [:stack, nil]
        ]))
      end
      scoped.order(:position).all
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

  end
end
