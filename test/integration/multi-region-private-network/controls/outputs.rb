# frozen_string_literal: true

require 'json'

# rubocop:disable Layout/LineLength
NETWORK_SELF_LINK_PATTERN = %r{projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/global/networks/[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$}
SUBNET_NAME_PATTERN = /[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$/
SUBNET_SELF_LINK_PATTERN = %r{projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/regions/[a-z]{2,}-[a-z]{2,}[0-9]/subnetworks/[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$}
# rubocop:enable Layout/LineLength

control 'outputs' do
  title 'Ensure module outputs match expectations'
  impact 1.0
  self_link = input('output_self_link')
  subnets = JSON.parse(input('output_subnets_json'), { symbolize_names: true })
  subnets_by_region = JSON.parse(input('output_subnets_by_region_json'), { symbolize_names: true })

  describe self_link do
    it { should_not be_nil }
    it { should match(NETWORK_SELF_LINK_PATTERN) }
  end

  subnets.each do |k, v|
    describe k do
      it { should match(SUBNET_NAME_PATTERN) }
      it { should cmp subnets_by_region[v[:region].to_sym][:name] }
    end
    describe v[:self_link] do
      it { should match(SUBNET_SELF_LINK_PATTERN) }
    end
    # subnets and subnets_by_region values should match execept that the former
    # has a 'region' value, and the latter has a 'name' value.
    compare_subnets_values = v.reject { |prop, _| prop == :region }
    compare_subnets_by_region_values = subnets_by_region[v[:region].to_sym].reject { |prop, _| prop == :name }
    describe compare_subnets_values do
      it { should cmp compare_subnets_by_region_values }
    end
  end
end
