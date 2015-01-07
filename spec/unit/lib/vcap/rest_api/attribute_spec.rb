require 'spec_helper'

module VCAP::CloudController
  describe VCAP::RestAPI::NamedAttribute do
    describe '#name' do
      it 'should return the name provided' do
        attr = NamedAttribute.new('some_attr')
        expect(attr.name).to eq('some_attr')
      end
    end

    describe '#default' do
      it 'should return nil if not provided' do
        attr = NamedAttribute.new('some_attr')
        expect(attr.default).to be_nil
      end

      it 'should return the default provided' do
        attr = NamedAttribute.new('some_attr', default: 'some default')
        expect(attr.default).to eq('some default')
      end
    end

    shared_examples 'operation list' do |opt, meth, desc|
      describe "##{meth}" do
        it "should return false when called with a non-#{desc} operation" do
          attr = NamedAttribute.new('some_attr')
          expect(attr.send(meth, :create)).to be false
        end

        it "should return true when called with an #{desc} operation" do
          attr = NamedAttribute.new('some_attr', opt => :read)
          expect(attr.send(meth, :create)).to be false
          expect(attr.send(meth, :read)).to be true
        end

        it "should work with a Symbol passed in via #{opt}" do
          attr = NamedAttribute.new('some_attr', opt => :read)
          expect(attr.send(meth, :create)).to be false
          expect(attr.send(meth, :read)).to be true
        end

        it "should work with an Array passed in via #{opt}" do
          attr = NamedAttribute.new('some_attr', opt => [:read, :update])
          expect(attr.send(meth, :create)).to be false
          expect(attr.send(meth, :read)).to be true
          expect(attr.send(meth, :update)).to be true
        end
      end
    end

    include_examples 'operation list', :exclude_in, :exclude_in?, 'excluded'
    include_examples 'operation list', :optional_in, :optional_in?, 'optional'
  end
end
