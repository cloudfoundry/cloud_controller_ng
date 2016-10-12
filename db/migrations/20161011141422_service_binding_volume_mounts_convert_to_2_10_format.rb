require 'cloud_controller/encryptor'
require 'json'

Sequel.migration do
  up do
    self[:service_bindings].each do |service_binding|
      next if service_binding[:volume_mounts].nil?

      mounts = JSON.parse(VCAP::CloudController::Encryptor.decrypt(service_binding[:volume_mounts], service_binding[:volume_mounts_salt]))

      next unless mounts.is_a?(Array) && !mounts.empty?

      mounts = mounts.map do |mount|
        if mount.key?('device')
          mount
        else
          {
            :device_type => 'shared',
            :container_dir => mount['container_path'],
            :driver => mount['private']['driver'],
            :mode => mount['mode'],
            :device => {
              :volume_id => mount['private']['group_id'],
              :config => mount['private']['config'],
            }
          }
        end
      end

      self[:service_bindings].filter(id: service_binding[:id]).update(
        volume_mounts: VCAP::CloudController::Encryptor.encrypt(JSON.dump(mounts), service_binding[:volume_mounts_salt])
      )
    end
  end

  down do
    self[:service_bindings].each do |service_binding|
      next if service_binding[:volume_mounts].empty?

      mounts = JSON.parse(VCAP::CloudController::Encryptor.decrypt(service_binding[:volume_mounts], service_binding[:volume_mounts_salt]))

      mounts = mounts.map do |mount|
        if mount.key?('private')
          mount
        else
          {
            :container_path => mount['container_dir'],
            :mode => mount['mode'],
            :private => {
              :driver => mount['driver'],
              :group_id => mount['device']['volume_id'],
              :config => mount['device']['config'],
            }
          }
        end
      end

      self[:service_bindings].filter(id: service_binding[:id]).update(
          volume_mounts: VCAP::CloudController::Encryptor.encrypt(JSON.dump(mounts), service_binding[:volume_mounts_salt])
      )
    end
  end
end