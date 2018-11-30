require 'spec_helper'
require 'models/helpers/process_types'

module VCAP::CloudController
  RSpec.describe ProcessTypes do
    describe '.legacy_webish?' do
      it_should_be_removed(by: '2020-04-01',
        explanation: 'we coerced all of the web-deployment-X process types to web circa dec 2018')

      it 'returns true for web-deployment-<guid>' do
        expect(ProcessTypes.legacy_webish?('web-deployment-11d44a0f-0535-449b-a265-4c01705d85a0')).to be true
      end

      it 'returns false for web' do
        expect(ProcessTypes.legacy_webish?('web')).to be false
      end

      it 'returns false for web-somethingelse' do
        expect(ProcessTypes.legacy_webish?('web-somethingelse')).to be false
      end

      it 'returns false for worker' do
        expect(ProcessTypes.legacy_webish?('worker')).to be false
      end
    end
  end
end
