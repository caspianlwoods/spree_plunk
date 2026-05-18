require 'spec_helper'
require 'generators/spree_plunk/install/install_generator'

RSpec.describe SpreePlunk::Generators::InstallGenerator do
  it 'defines a migrate option enabled by default' do
    expect(described_class.class_options.fetch(:migrate).default).to be(true)
  end
end
