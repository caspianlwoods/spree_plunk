module SpreePlunk
  class Base
    prepend ::Spree::ServiceModule::Base

    private

    def noop_result(reason)
      ::Spree::ServiceModule::Result.new(true, { skipped: true, reason: reason })
    end
  end
end
