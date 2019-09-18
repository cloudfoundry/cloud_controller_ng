module VCAP::CloudController
  class JobWarningModel < Sequel::Model(:job_warnings)
    many_to_one :job, class: 'VCAP::CloudController::PollableJobModel'

    import_attributes :detail, :job_guid
    export_attributes :detail
  end
end
