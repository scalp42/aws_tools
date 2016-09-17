# Cookbook Name:: s3encrypt
# Recipe:: default
# Copyright (c) 2016 Dave Tashner, All Rights Reserved.

# Set the default AWS_REGION so that the s3encrypt gem is happy.
# This value is unfortunately not immediately available in instance metadata.
ENV['AWS_REGION'] = node['s3encrypt']['aws_region']

# Include the aws-sdk and JSON libraries
%w{aws-sdk json s3encrypt}.each do |g|
  chef_gem g do
    action :install
    compile_time true
  end
end

# Require necessary gems and libraries
require 'aws-sdk'
require 'json'
require 's3encrypt'

# Decrypt and download the secrets file from the S3 location specified in ~/attributes/default.rb
hash = S3encrypt.getfile_as_json(node['s3encrypt']['s3_secret_path'], node['s3encrypt']['s3_bucket'], node['s3encrypt']['encryption_context'])

# Use the in-memory `hash` variable to inject the secrets into an arbitrary file
file "#{::Chef::Config['file_cache_path']}/delete_me" do
  content "#{hash['user1']}"
  sensitive true
end
