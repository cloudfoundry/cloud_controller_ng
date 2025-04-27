require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::RestAPI::NamedAttribute do
    describe '#name' do
      it 'returns the name provided' do
        attr = NamedAttribute.new('some_attr')
        expect(attr.name).to eq('some_attr')
      end
    end

    describe '#default' do
      it 'returns nil if not provided' do
        attr = NamedAttribute.new('some_attr')
        expect(attr.default).to be_nil
      end

      it 'returns the default provided' do
        attr = NamedAttribute.new('some_attr', default: 'some default')
        expect(attr.default).to eq('some default')
      end
    end

    shared_examples 'operation list' do |opt, meth, desc|
      describe "##{meth}" do
        it "returns false when called with a non-#{desc} operation" do
          attr = NamedAttribute.new('some_attr')
          expect(attr.send(meth, :create)).to be false
        end

        it "returns true when called with an #{desc} operation" do
          attr = NamedAttribute.new('some_attr', opt => :read)
          expect(attr.send(meth, :create)).to be false
          expect(attr.send(meth, :read)).to be true
        end

        it "works with a Symbol passed in via #{opt}" do
          attr = NamedAttribute.new('some_attr', opt => :read)
          expect(attr.send(meth, :create)).to be false
          expect(attr.send(meth, :read)).to be true
        end

        it "works with an Array passed in via #{opt}" do
          attr = NamedAttribute.new('some_attr', opt => %i[read update])
          expect(attr.send(meth, :create)).to be false
          expect(attr.send(meth, :read)).to be true
          expect(attr.send(meth, :update)).to be true
        end
      end
    end

    it_behaves_like 'operation list', :exclude_in, :exclude_in?, 'excluded'
    it_behaves_like 'operation list', :optional_in, :optional_in?, 'optional'
    it_behaves_like 'operation list', :redact_in, :redact_in?, 'redacted'
  end
end
