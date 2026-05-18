module SpreePlunk
  class SyncError < StandardError
    attr_reader :context, :error_code, :status

    def initialize(message, status: nil, error_code: nil, context: {})
      super(message)
      @status = status
      @error_code = error_code
      @context = context
    end
  end

  class RetryableSyncError < SyncError; end
  class DiscardableSyncError < SyncError; end
end
