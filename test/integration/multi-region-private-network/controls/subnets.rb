# frozen_string_literal: true

require 'ipaddr'
require 'json'
require 'rspec/expectations'

SUBNET_MATCHER = %r{/projects/(?<project>[^/]+)/regions/(?<region>[^/]+)/subnetworks/(?<name>.+)$}

RSpec::Matchers.define :be_in_cidr do |network|
  match do |subnet|
    IPAddr.new(network).include?(subnet)
  end
end

RSpec::Matchers.define :have_cidr_size do |size|
  match do |cidr|
    IPAddr.new(cidr).prefix == size
  end
end

# rubocop:disable Metrics/BlockLength
control 'subnets' do
  title 'Ensure VPC subnetworks are configured as expected'
  impact 1.0
  subnets_by_name = JSON.parse(input('output_subnets_by_name_json'), { symbolize_names: true })
  name = input('input_name')
  cidrs = JSON.parse(input('output_cidrs_json'), { symbolize_names: true })
  secondaries = cidrs[:secondaries] || {}
  options = JSON.parse(input('output_options_json'), { symbolize_names: true })
  flow_logs = JSON.parse(input('output_flow_logs_json'), { symbolize_names: true })

  subnets_by_name.each_value do |v|
    params = v[:self_link].match(SUBNET_MATCHER).named_captures
    subnet = google_compute_subnetwork(project: params['project'], region: params['region'], name: params['name'])
    describe subnet do
      it { should exist }
      its('name') { should match(/^#{name}(?:-[a-z]{2}){2}[1-9]$/) }
      its('description') { should be_nil }
      its('region') { should match(/#{v[:region]}$/) }
      its('ip_cidr_range') { should be_in_cidr(cidrs[:primary_ipv4_cidr]) }
      its('ip_cidr_range') { should have_cidr_size(cidrs[:primary_ipv4_subnet_size]) }
      its('purpose') { should cmp 'PRIVATE' }
      its('role') { should be_nil }
      its('private_ip_google_access') { should cmp true }
      its('log_config.enable') { should cmp !flow_logs.nil? }
      if secondaries.empty?
        its('secondary_ip_ranges') { should be_nil }
      else
        its('secondary_ip_ranges.length') { should eq secondaries.keys.length }
        subnet.secondary_ip_ranges.each do |range|
          describe range do
            its('ip_cidr_range') { should be_in_cidr(secondaries[range.range_name.to_sym][:ipv4_cidr]) }
            its('ip_cidr_range') { should have_cidr_size(secondaries[range.range_name.to_sym][:ipv4_subnet_size]) }
          end
        end
      end
      if options[:ipv6_ula]
        its('private_ipv6_google_access') { should cmp 'ENABLE_OUTBOUND_VM_ACCESS_TO_GOOGLE' }
      else
        its('private_ipv6_google_access') { should cmp 'DISABLE_GOOGLE_ACCESS' }
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
