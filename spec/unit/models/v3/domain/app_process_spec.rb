require 'spec_helper'
require 'models/v3/domain/app_process'

module VCAP::CloudController
  describe AppProcess do
    let(:opts) { { guid: 'my_guid' } }

    it 'defaults the name of a process when it has not been provided' do
      expect(AppProcess.new(opts).name).to eq('v3-proc-web-my_guid')
    end

    it 'defaults the type of a process to web when it has not been provided' do
      expect(AppProcess.new(opts).type).to eq('web')
    end
  end
end
