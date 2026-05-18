module SpreePlunk
  class Engine < Rails::Engine
    require 'spree/core'

    isolate_namespace Spree
    engine_name 'spree_plunk'

    config.generators do |g|
      g.test_framework :rspec
    end

    config.paths.add 'app/subscribers', eager_load: true

    initializer 'spree_plunk.environment', before: :load_config_initializers do |_app|
      SpreePlunk::Config = SpreePlunk::Configuration.new
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |path|
        Rails.configuration.cache_classes ? require(path) : load(path)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
