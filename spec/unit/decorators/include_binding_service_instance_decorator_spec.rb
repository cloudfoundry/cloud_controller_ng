require 'db_spec_helper'
require 'decorators/include_binding_service_instance_decorator'

module VCAP
  module CloudController
    def self.can_be_decorated_with_include_binding_service_instance_decorator(klazz)
      RSpec.describe IncludeBindingServiceInstanceDecorator do
        subject(:decorator) { described_class }
        let(:bindings) { Array.new(3) { klazz.make } }
        let(:instances) {
          bindings.map { |b| Presenters::V3::ServiceInstancePresenter.new(b.service_instance).to_hash }
        }

        it 'decorates the given hash with service instances from bindings' do
          dict = { foo: 'bar' }
          hash = subject.decorate(dict, bindings)
          expect(hash[:foo]).to eq('bar')
          expect(hash[:included][:service_instances]).to match_array(instances)
        end

        it 'does not overwrite other included fields' do
          dict = { foo: 'bar', included: { fruits: ['tomato', 'banana'] } }
          hash = subject.decorate(dict, bindings)
          expect(hash[:foo]).to eq('bar')
          expect(hash[:included][:service_instances]).to match_array(instances)
          expect(hash[:included][:fruits]).to match_array(['tomato', 'banana'])
        end

        it 'does not include duplicates' do
          hash = subject.decorate({}, bindings << klazz.make(service_instance: bindings[0].service_instance))
          expect(hash[:included][:service_instances]).to have(3).items
        end

        describe '.match?' do
          it 'matches include arrays containing "app"' do
            expect(decorator.match?(['potato', 'service_instance', 'turnip'])).to be_truthy
          end

          it 'does not match other include arrays' do
            expect(decorator.match?(['potato', 'turnip'])).to be_falsey
          end
        end
      end
    end

    [
      ServiceBinding,
      ServiceKey,
      RouteBinding
    ].each do |type|
      can_be_decorated_with_include_binding_service_instance_decorator(type)
    end
  end
end
