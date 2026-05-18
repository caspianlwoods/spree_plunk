require 'spree_core'
require 'spree_plunk/configuration'
require 'spree_plunk/engine'
require 'spree_plunk/event_names'
require 'spree_plunk/version'

module SpreePlunk
  mattr_accessor :queue

  def self.queue
    @@queue ||= Spree.queues.default
  end
end
