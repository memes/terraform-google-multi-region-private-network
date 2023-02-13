# frozen_string_literal: true

require 'json'

NETWORK_MATCHER = %r{/projects/(?<project>[^/]+)/global/networks/(?<name>.+)$}

control 'networks' do
  title 'Ensure VPC network is configured as expected'
  impact 1.0
  self_link = input('output_self_link')
  name = input('input_name')
  description = input('input_description', value: 'custom vpc')
  expected_number_subnets = input('input_regions').gsub(/(?:[\[\]]|\\?")/, '').gsub(', ', ',').split(',').length
  options = JSON.parse(input('output_options_json'), { symbolize_names: true })

  params = self_link.match(NETWORK_MATCHER).named_captures
  describe google_compute_network(project: params['project'], name: params['name']) do
    it { should exist }
    its('name') { should cmp name }
    its('description') { should cmp description }
    its('subnetworks.length') { should cmp expected_number_subnets }
    its('auto_create_subnetworks') { should cmp false }
    its('routing_config.routing_mode') { should cmp options[:routing_mode] }
    its('peerings') { should be_nil }
    its('mtu') { should cmp options[:mtu] }
  end
end
