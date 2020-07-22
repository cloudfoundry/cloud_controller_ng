require 'presenters/v3/app_manifest_presenter'
require 'json-diff'

module VCAP::CloudController
  class SpaceDiffManifest
    def self.filter_manifest_app_hash(manifest_app_hash)
      if manifest_app_hash.key? 'sidecars'
        manifest_app_hash['sidecars'] = manifest_app_hash['sidecars'].map do |hash|
          hash.slice(
            'name',
            'command',
            'process_types',
            'memory'
          )
        end
        manifest_app_hash = manifest_app_hash.except('sidecars') if manifest_app_hash['sidecars'] == [{}]
      end
      if manifest_app_hash.key? 'processes'
        manifest_app_hash['processes'] = manifest_app_hash['processes'].map do |hash|
          hash.slice(
            'type',
            'command',
            'disk_quota',
            'health-check-http-endpoint',
            'health-check-invocation-timeout',
            'health-check-type',
            'instances',
            'memory',
            'timeout'
          )
        end
        manifest_app_hash = manifest_app_hash.except('processes') if manifest_app_hash['processes'] == [{}]
      end

      if manifest_app_hash.key? 'services'
        manifest_app_hash['services'] = manifest_app_hash['services'].map do |hash|
          hash.slice(
            'name',
            'parameters'
          )
        end
        manifest_app_hash = manifest_app_hash.except('services') if manifest_app_hash['services'] == [{}]
      end

      if manifest_app_hash.key? 'metadata'
        manifest_app_hash['metadata'] = manifest_app_hash['metadata'].map do |hash|
          hash.slice(
            'labels',
            'annotations'
          )
        end
        manifest_app_hash = manifest_app_hash.except('metadata') if manifest_app_hash['metadata'] == [{}]
      end
      manifest_app_hash
    end

    def self.generate_diff(app_manifests, space)
      json_diff = []
      recognized_top_level_keys = NamedAppManifestMessage.allowed_keys.map(&:to_s)
      app_manifests.each_with_index do |manifest_app_hash, index|
        manifest_app_hash = SpaceDiffManifest.filter_manifest_app_hash(manifest_app_hash)
        existing_app = space.app_models.find { |app| app.name == manifest_app_hash['name'] }

        if existing_app.nil?
          existing_app_hash = {}
        else
          manifest_presenter = Presenters::V3::AppManifestPresenter.new(
            existing_app,
            existing_app.service_bindings,
            existing_app.routes,
          )
          existing_app_hash = manifest_presenter.to_hash.deep_stringify_keys['applications'][0]
          web_process_hash = existing_app_hash['processes'].find { |p| p['type'] == 'web' }
          existing_app_hash = existing_app_hash.merge(web_process_hash) if web_process_hash
        end

        manifest_app_hash.each do |key, value|
          next unless recognized_top_level_keys.include?(key)

          existing_value = existing_app_hash[key]

          key_diffs = JsonDiff.diff(
            existing_value,
            value,
            include_was: true,
          )

          key_diffs.each do |diff|
            diff['path'] = "/applications/#{index}/#{key}" + diff['path']

            if diff['op'] == 'replace' && diff['was'].nil?
              diff['op'] = 'add'
            end

            json_diff << diff
          end
        end
      end

      json_diff
    end
  end
end
