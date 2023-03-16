# frozen_string_literal: true

require 'json'

control 'default-vpc-route' do
  title 'Ensure default VPC route matches expectations'
  impact 1.0
  self_link = input('output_self_link')
  options = JSON.parse(input('output_options_json'), { symbolize_names: true })
  project_id = input('input_project_id')

  expected_default_routes_count = options[:delete_default_routes] ? 0 : 1
  describe google_compute_routes(project: project_id).where(network: self_link, dest_range: '0.0.0.0/0',
                                                            priority: 1000, name: /default-route-\h{16}/) do
    its('count') { should eq expected_default_routes_count }
  end
end

control 'restricted-api-route' do
  title 'Ensure route to Google restricted API endpoint matches expectations'
  impact 1.0
  self_link = input('output_self_link')
  options = JSON.parse(input('output_options_json'), { symbolize_names: true })
  project_id = input('input_project_id')
  name = input('input_name')

  expected_restricted_apis_count = options[:restricted_apis] ? 1 : 0
  describe google_compute_routes(project: project_id).where(network: self_link, dest_range: '199.36.153.4/30',
                                                            name: "#{name}-restricted-apis") do
    its('count') { should eq expected_restricted_apis_count }
    unless expected_restricted_apis_count.zero?
      its('names') { should include "#{name}-restricted-apis" }
      its('descriptions') { should include 'Route for restricted Google API access' }
      its('next_hop_gateways') { should include "https://www.googleapis.com/compute/v1/projects/#{project_id}/global/gateways/default-internet-gateway" }
    end
  end
end

control 'tagged-nat-route' do
  title 'Ensure tagged route to NAT matches expectations'
  impact 1.0
  self_link = input('output_self_link')
  options = JSON.parse(input('output_options_json'), { symbolize_names: true })
  project_id = input('input_project_id')
  name = input('input_name')
  tags = options[:nat_tags]

  expected_tagged_nat_count = options[:nat] && tags.count.positive? ? 1 : 0
  describe google_compute_routes(project: project_id).where(network: self_link, dest_range: '0.0.0.0/0',
                                                            name: "#{name}-tagged-nat") do
    its('count') { should eq expected_tagged_nat_count }
    unless expected_tagged_nat_count.zero?
      its('descriptions') { should include 'Route to NAT gateway for tagged resources' }
      its('next_hop_gateways') { should include "https://www.googleapis.com/compute/v1/projects/#{project_id}/global/gateways/default-internet-gateway" }
      its('priorities') { should include 900 }
      its('tags') { should include tags }
    end
  end
end
