# frozen_string_literal: true

require "spec_helper"

::RSpec.describe ::ContractedValue do

  it "has a version number" do
    expect(described_class::VERSION).not_to eq(nil)
  end

end
