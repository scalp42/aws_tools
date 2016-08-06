#
# Cookbook Name:: s3encrypt
# Recipe:: default
#
# Copyright (c) 2016 Dave Tashner, All Rights Reserved.
ENV['AWS_REGION'] = node['s3encrypt']['aws_region']
# Build s3encrypt since it's not yet available in RubyGems
include_recipe 's3encrypt::build_s3encrypt'

# Include the aws-sdk and JSON libraries
%w{aws-sdk json}.each do |g|
  chef_gem g do
    action :install
    compile_time true
  end
end

# Require necessary gems and libraries
require 'aws-sdk'
require 'json'
require 's3encrypt'

S3encrypt.getfile(node['s3encrypt']['local_secret_path'], node['s3encrypt']['s3_secret_path'], node['s3encrypt']['s3_bucket'], node['s3encrypt']['encryption_context'])

file = IO.read(node['s3encrypt']['local_secret_path'])
hash = JSON.parse(file)

# Remove secrets from filesystem
execute 'delete-secrets' do
  command "rm -f #{node['s3encrypt']['local_secret_path']}"
  sensitive true
end

file '/tmp/secrets' do
  content "#{hash}"
  sensitive true
end
