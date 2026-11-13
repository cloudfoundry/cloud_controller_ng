require 'spec_helper'
require 'mixins/internal_or_root_api'

module CloudFoundry
  module Middleware
    RSpec.describe 'InternalOrRootApi mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::InternalOrRootApi }.new
      end

      def request_for(path)
        instance_double(ActionDispatch::Request, fullpath: path)
      end

      describe '#internal_api?' do
        it 'returns truthy for /internal paths' do
          expect(implementor).to be_internal_api(request_for('/internal/v4/asg_latest_update'))
        end

        it 'returns falsy for non-internal paths' do
          expect(implementor).not_to be_internal_api(request_for('/v3/apps'))
        end
      end

      describe '#root_api?' do
        ['/v2/info', '/v3', '/', '/healthz'].each do |path|
          it "returns truthy for #{path}" do
            expect(implementor).to be_root_api(request_for(path))
          end
        end

        ['/v2/apps', '/v3/apps', '/v2/info/extra'].each do |path|
          it "returns falsy for #{path}" do
            expect(implementor).not_to be_root_api(request_for(path))
          end
        end
      end
    end
  end
end
