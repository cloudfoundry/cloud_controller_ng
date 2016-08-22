require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IsolationSegmentModel do
    let(:isolation_segment) { IsolationSegmentModel.make }

    describe 'validations' do
      it 'requires a name' do
        expect {
          IsolationSegmentModel.make(name: nil)
        }.to raise_error(Sequel::ValidationFailed)
      end

      it 'requires a non blank name' do
        expect {
          IsolationSegmentModel.make(name: '')
        }.to raise_error(Sequel::ValidationFailed)
      end

      it 'requires a unique name' do
        IsolationSegmentModel.make(name: 'segment1')

        expect {
          IsolationSegmentModel.make(name: 'segment1')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names are case insensitive and must be unique')
      end

      it 'uniqueness is case insensitive' do
        IsolationSegmentModel.make(name: 'lowercase')

        expect {
          IsolationSegmentModel.make(name: 'lowerCase')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names are case insensitive and must be unique')
      end

      it 'should allow standard ascii characters' do
        expect {
          IsolationSegmentModel.make(name: "A -_- word 2!?()\'\"&+.")
        }.to_not raise_error
      end

      it 'should allow backslash characters' do
        expect {
          IsolationSegmentModel.make(name: 'a \\ word')
        }.to_not raise_error
      end

      it 'should allow unicode characters' do
        expect {
          IsolationSegmentModel.make(name: '防御力¡')
        }.to_not raise_error
      end

      it 'should not allow newline characters' do
        expect {
          IsolationSegmentModel.make(name: "a \n word")
        }.to raise_error(Sequel::ValidationFailed)
      end

      it 'should not allow escape characters' do
        expect {
          IsolationSegmentModel.make(name: "a \e word")
        }.to raise_error(Sequel::ValidationFailed)
      end
    end
  end
end
