# frozen_string_literal: true

ruby '3.3.6'

source 'https://rubygems.org/'
gem 'kitchen-terraform', '~> 7.0.2'
# Nori 2.7 causes problems with inspec-gcp, so pin to 2.6
# See https://github.com/inspec/inspec-gcp/issues/596
gem 'nori', '~> 2.6.0'
group :dev do
  gem 'reek', '~> 6.5.0', require: false
  # Transitive dependency on rubocop v1.25.1 via kitchen-terraform
  # gem 'rubocop', '~> 1.63.4', require: false
end
