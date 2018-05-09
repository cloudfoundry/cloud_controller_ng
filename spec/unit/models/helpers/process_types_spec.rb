require 'spec_helper'
require 'models/helpers/process_types'

module VCAP::CloudController
  RSpec.describe ProcessTypes do
    describe '.webish?' do
      it 'returns true for web' do
        expect(ProcessTypes.webish?('web')).to be true
      end

      it 'returns true for web-deployment-<guid>' do
        expect(ProcessTypes.webish?('web-deployment-11d44a0f-0535-449b-a265-4c01705d85a0')).to be true
      end

      it 'returns false for something-web-deployment-<guid>' do
        expect(ProcessTypes.webish?('something-web-deployment-11d44a0f-0535-449b-a265-4c01705d85a0')).to be false
      end

      it 'returns false for web-somethingelse' do
        expect(ProcessTypes.webish?('web-somethingelse')).to be false
      end
    end
  end
end
