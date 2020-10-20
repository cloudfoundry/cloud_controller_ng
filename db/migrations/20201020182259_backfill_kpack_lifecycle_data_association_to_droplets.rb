Sequel.migration do
  up do
    unassociated_kpack_lifecycle_data = self[:kpack_lifecycle_data].select(:id, :build_guid).where(droplet_guid: nil).exclude(build_guid: nil)

    unassociated_kpack_lifecycle_data.each do |kld|
      droplet = self[:droplets].select(:guid).where(build_guid: kld[:build_guid]).first

      # there may not have been a droplet created yet for the build
      next if droplet.nil?

      self[:kpack_lifecycle_data].where(id: kld[:id]).update(droplet_guid: droplet[:guid])
    end
  end

  down do
    # unimplemented
  end
end
