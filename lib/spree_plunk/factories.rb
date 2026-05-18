require_relative 'testing_support/defaults'

Dir["#{File.dirname(__FILE__)}/testing_support/factories/**"].sort.each do |path|
  load File.expand_path(path)
end
