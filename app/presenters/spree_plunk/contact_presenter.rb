module SpreePlunk
  class ContactPresenter
    def initialize(user: nil, subscriber: nil, address: nil, email: nil, store: nil)
      @user = user || subscriber&.user || address&.user
      @subscriber = subscriber
      @address = address
      @store = store
      @email = email
    end

    def call(subscribed:)
      payload = {
        email: resolved_email,
        subscribed: subscribed,
        data: contact_data
      }

      payload.delete(:data) if payload[:data].empty?
      payload
    end

    private

    attr_reader :user, :subscriber, :address, :store, :email

    def resolved_email
      email.presence || subscriber&.email.presence || user&.email.presence
    end

    def contact_data
      {
        external_user_id: user&.id,
        store_code: store&.code,
        first_name: first_name,
        last_name: last_name,
        phone: phone,
        accepts_email_marketing: accepts_email_marketing,
        city: resolved_address&.city,
        region: resolved_address&.state_text,
        country: resolved_address&.country_name,
        zip: resolved_address&.zipcode,
        order_count: order_count,
        last_order_number: last_order&.number,
        last_order_total: last_order&.total&.to_f
      }.reject { |_key, value| value.nil? || value == '' }
    end

    def first_name
      user&.first_name.presence || resolved_address&.first_name.presence
    end

    def last_name
      user&.last_name.presence || resolved_address&.last_name.presence
    end

    def phone
      user&.phone.presence || resolved_address&.phone.presence
    end

    def accepts_email_marketing
      if subscriber.respond_to?(:accepts_email_marketing)
        subscriber.accepts_email_marketing
      elsif user.respond_to?(:accepts_email_marketing)
        user.accepts_email_marketing
      end
    end

    def resolved_address
      @resolved_address ||= address || user&.bill_address || user&.ship_address
    end

    def order_count
      return unless user.respond_to?(:completed_orders)

      user.completed_orders.count
    end

    def last_order
      return unless user.respond_to?(:completed_orders)

      @last_order ||= user.completed_orders.reorder(completed_at: :desc, id: :desc).first
    end
  end
end
