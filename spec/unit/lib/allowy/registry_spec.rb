# frozen_string_literal: true

require_relative 'allowy_spec_helper'

module Allowy
  RSpec.describe Registry do
    let(:context) { 123 }

    subject(:registry) { described_class.new(context) }

    describe '#access_control_for!' do
      it 'finds AC by appending Access to the subject' do
        expect(registry.access_control_for!(Sample.new)).to be_a(SampleAccess)
      end

      it 'finds AC by appending custom suffix to the subject' do
        custom_registry = described_class.new(context, access_suffix: 'Permission')
        expect(custom_registry.access_control_for!(Sample.new)).to be_a(SamplePermission)
      end

      it 'raises on invalid option' do
        expect { described_class.new(context, foo: 'incorrect option') }.to raise_error(/unknown key/i)
      end

      it 'finds AC when the subject is a class' do
        expect(registry.access_control_for!(Sample)).to be_a(SampleAccess)
      end

      it 'raises when AC is not found by the subject' do
        expect { registry.access_control_for!(123) }.to raise_error(UndefinedAccessControl) do |err|
          expect(err.message).to include('123')
        end
      end

      it 'raises when subject is nil' do
        expect { registry.access_control_for!(nil) }.to raise_error(UndefinedAccessControl)
      end

      it 'returns NilClassAccess when subject is nil and NilClassAccess is defined' do
        nil_class_access = Class.new do
          include Allowy::AccessControl
        end
        stub_const('NilClassAccess', nil_class_access)
        expect(registry.access_control_for!(nil)).to be_a(nil_class_access)
      end

      it 'returns the same AC instance' do
        first = registry.access_control_for!(Sample)
        second = registry.access_control_for!(Sample)
        expect(first).to equal(second)
      end

      it 'supports objects that provide source_class method (such as Draper)' do
        decorator_class = Class.new do
          def self.source_class
            Sample
          end
        end
        decorated_object = decorator_class.new
        expect(registry.access_control_for!(decorated_object)).to be_a(SampleAccess)
      end
    end
  end
end
