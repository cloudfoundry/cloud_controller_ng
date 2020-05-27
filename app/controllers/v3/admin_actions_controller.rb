require 'jobs/v3/buildpack_cache_cleanup'

class AdminActionsController < ApplicationController
  def clear_buildpack_cache
    unauthorized! unless permission_queryer.can_write_globally?

    pollable_job = Jobs::Enqueuer.new(Jobs::V3::BuildpackCacheCleanup.new, queue: Jobs::Queues.generic).enqueue_pollable
    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end
end
