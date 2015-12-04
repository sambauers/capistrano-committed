require 'spec_helper'

describe Capistrano::Committed do
  it 'has a version number' do
    expect(Capistrano::Committed::VERSION).not_to be nil
  end
end
