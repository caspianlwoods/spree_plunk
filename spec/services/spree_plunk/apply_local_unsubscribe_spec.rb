require 'spec_helper'

RSpec.describe SpreePlunk::ApplyLocalUnsubscribe do
  before do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'removes the matching newsletter subscriber and clears user marketing without re-enqueuing outbound sync jobs' do
    user = create(:user, email: 'newsletter@example.com', accepts_email_marketing: true)
    subscriber = create(:newsletter_subscriber, :verified, user: user, email: user.email)
    clear_enqueued_jobs

    result = nil

    expect {
      result = described_class.call(email: subscriber.email)
    }.to change(Spree::NewsletterSubscriber, :count).by(-1)

    aggregate_failures do
      expect(result).to be_success
      expect(result.value).to include(
        email: 'newsletter@example.com',
        unsubscribed: true,
        subscriber_removed: true,
        user_updated: true
      )
      expect(user.reload.accepts_email_marketing).to be(false)
      expect(enqueued_jobs.map { |job| job[:job] }).not_to include(
        SpreePlunk::UpsertContactJob,
        SpreePlunk::SubscribeJob,
        SpreePlunk::UnsubscribeJob,
        SpreePlunk::TrackEventJob
      )
    end
  end

  it 'clears user marketing even when there is no newsletter subscriber row' do
    user = create(:user, email: 'customer@example.com', accepts_email_marketing: true)

    result = described_class.call(email: user.email)

    aggregate_failures do
      expect(result).to be_success
      expect(result.value).to include(
        email: 'customer@example.com',
        unsubscribed: true,
        subscriber_removed: false,
        user_updated: true
      )
      expect(user.reload.accepts_email_marketing).to be(false)
    end
  end

  it 'acknowledges already-cleared local state for a matching user email' do
    user = create(:user, email: 'customer@example.com', accepts_email_marketing: false)

    result = described_class.call(email: user.email)

    expect(result.value).to include(
      email: 'customer@example.com',
      unsubscribed: true,
      subscriber_removed: false,
      user_updated: false
    )
  end

  it 'no-ops when no local subscriber or user matches the email' do
    result = described_class.call(email: 'missing@example.com')

    expect(result.value).to include(skipped: true, reason: 'local_email_not_found')
  end
end
