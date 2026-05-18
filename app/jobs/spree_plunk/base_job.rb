module SpreePlunk
  class BaseJob < ApplicationJob
    queue_as SpreePlunk.queue
  end
end
