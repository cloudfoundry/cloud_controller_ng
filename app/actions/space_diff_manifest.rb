require 'presenters/v3/app_manifest_presenter'
require 'messages/app_manifest_message'
require 'json-diff'

module VCAP::CloudController
  class SpaceDiffManifest
    IDENTIFIERS = {
      'processes' => 'type',
      'routes' => 'route',
      'sidecars' => 'name',
    }.freeze

    class << self
      # rubocop:todo Metrics/CyclomaticComplexity
      def generate_diff(app_manifests, space)
        json_diff = []

        recognized_top_level_keys = AppManifestMessage.allowed_keys.map(&:to_s).map(&:dasherize)

        app_manifests = normalize_units(app_manifests)
        app_manifests.each_with_index do |manifest_app_hash, index|
          manifest_app_hash = filter_manifest_app_hash(manifest_app_hash)
          existing_app = space.app_models.find { |app| app.name == manifest_app_hash['name'] }

          if existing_app.nil?
            existing_app_hash = {}
          else
            manifest_presenter = Presenters::V3::AppManifestPresenter.new(
              existing_app,
              existing_app.service_bindings,
              existing_app.route_mappings,
            )
            existing_app_hash = manifest_presenter.to_hash.deep_stringify_keys['applications'][0]
            web_process_hash = existing_app_hash['processes'].find { |p| p['type'] == 'web' }
            existing_app_hash = existing_app_hash.merge(web_process_hash) if web_process_hash

            # Account for the fact that older manifests may have a hyphen for disk-quota
            if manifest_app_hash.key?('disk-quota')
              existing_app_hash['disk-quota'] = existing_app_hash['disk_quota']
              recognized_top_level_keys << 'disk-quota'
            end
          end

          manifest_app_hash.each do |key, value|
            next unless recognized_top_level_keys.include?(key)

            existing_value = existing_app_hash[key]

            needs_pruning = %w[processes sidecars routes].include?(key)
            nested_attribute_exists = existing_value.present? && needs_pruning

            if nested_attribute_exists
              remove_default_missing_fields(existing_value, key, value)
            end

            # To preserve backwards compability, we've decided to skip diffs that satisfy this conditon
            next if !nested_attribute_exists && %w[disk_quota disk-quota memory].include?(key)

            key_diffs = JsonDiff.diff(
              existing_value,
              value,
              include_was: true,
              similarity: create_similarity
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
        # rubocop:enable Metrics/CyclomaticComplexity

        json_diff
      end

      private

      # rubocop:todo Metrics/CyclomaticComplexity
      def filter_manifest_app_hash(manifest_app_hash)
        if manifest_app_hash.key? 'sidecars'
          manifest_app_hash['sidecars'] = manifest_app_hash['sidecars'].map do |hash|
            hash.slice(
              'name',
              'command',
              'process_types',
              'memory'
            )
          end
          manifest_app_hash['sidecars'] = normalize_units(manifest_app_hash['sidecars'])
          manifest_app_hash = manifest_app_hash.except('sidecars') if manifest_app_hash['sidecars'] == [{}]
        end
        if manifest_app_hash.key? 'processes'
          manifest_app_hash['processes'] = manifest_app_hash['processes'].map do |hash|
            hash.slice(
              'type',
              'command',
              'disk_quota',
              'log-rate-limit-per-second',
              'health-check-http-endpoint',
              'health-check-invocation-timeout',
              'health-check-type',
              'instances',
              'memory',
              'timeout'
            )
          end
          manifest_app_hash['processes'] = normalize_units(manifest_app_hash['processes'])
          manifest_app_hash = manifest_app_hash.except('processes') if manifest_app_hash['processes'] == [{}]
        end

        if manifest_app_hash.key? 'services'
          manifest_app_hash['services'] = manifest_app_hash['services'].map do |hash|
            if hash.is_a? String
              hash
            else
              hash.slice(
                'name',
                'parameters'
              )
            end
          end
          manifest_app_hash = manifest_app_hash.except('services') if manifest_app_hash['services'] == [{}]
        end

        if manifest_app_hash.key? 'metadata'
          manifest_app_hash['metadata'] = manifest_app_hash['metadata'].slice(
            'labels',
            'annotations'
          )
          manifest_app_hash = manifest_app_hash.except('metadata') if manifest_app_hash['metadata'] == {}
        end

        manifest_app_hash
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def create_similarity
        ->(before, after) do
          return nil unless before.is_a?(Hash) && after.is_a?(Hash)

          if before.key?('type') && after.key?('type')
            return before['type'] == after['type'] ? 1.0 : 0.0
          elsif before.key?('name') && after.key?('name')
            return before['name'] == after['name'] ? 1.0 : 0.0
          end

          nil
        end
      end

      def normalize_units(manifest_app_hash)
        byte_measurement_key_words = ['memory', 'disk-quota', 'disk_quota']
        manifest_app_hash.each_with_index do |process_hash, index|
          byte_measurement_key_words.each do |key|
            value = process_hash[key]
            manifest_app_hash[index][key] = convert_to_mb(value, key) unless value.nil?
          end
        end

        byte_measurement_key_words = ['log-rate-limit-per-second']
        manifest_app_hash.each_with_index do |process_hash, index|
          byte_measurement_key_words.each do |key|
            value = process_hash[key]
            manifest_app_hash[index][key] = normalize_unit(value, key) unless value.nil?
          end
        end
        manifest_app_hash
      end

      def convert_to_mb(human_readable_byte_value, attribute_name)
        byte_converter.convert_to_mb(human_readable_byte_value).to_s + 'M'
      rescue ByteConverter::InvalidUnitsError
        "#{attribute_name} must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB"
      rescue ByteConverter::NonNumericError
        "#{attribute_name} is not a number"
      end

      def normalize_unit(non_normalized_value, attribute_name)
        if %w(-1 0).include?(non_normalized_value.to_s)
          non_normalized_value.to_s
        else
          byte_converter.human_readable_byte_value(byte_converter.convert_to_b(non_normalized_value))
        end
      rescue ByteConverter::InvalidUnitsError
        "#{attribute_name} must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB"
      rescue ByteConverter::NonNumericError
        "#{attribute_name} is not a number"
      end

      def byte_converter
        ByteConverter.new
      end

      def remove_default_missing_fields(existing_value, current_key, value)
        identifying_field = IDENTIFIERS[current_key]
        existing_value.each_with_index do |resource, i|
          manifest_app_hash_resource = value.find { |hash_resource| hash_resource[identifying_field] == resource[identifying_field] }
          if manifest_app_hash_resource.nil?
            existing_value.delete_at(i)
          else
            resource.each do |k, v|
              if manifest_app_hash_resource[k].nil?
                existing_value[i].delete(k)
              end
            end
          end
        end
      end
    end
  end
end
