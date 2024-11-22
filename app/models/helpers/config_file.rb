# frozen_string_literal: true
module VCAP::CloudController
    class ConfigFile
      def initialize(file_path)
        @hash = YAMLConfig.safe_load_file(file_path).tap do |h|
          Schema.validate(h)
        end
      end

      def stacks
        @hash['stacks']
      end

      def deprecated_stacks
        @hash['deprecated_stacks']
      end

      def default
        @hash['default']
      end

      Schema = Membrane::SchemaParser.parse do
        {
          'default' => String,
          'stacks' => [{
                         'name' => String,
                         'description' => String,
                         optional('build_rootfs_image') => String,
                         optional('run_rootfs_image') => String
                       }],
          optional('deprecated_stacks') => [
            String
          ]
        }
      end
    end
  end
