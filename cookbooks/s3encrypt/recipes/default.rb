# Cookbook Name:: s3encrypt
# Recipe:: default
# Copyright (c) 2016 Dave Tashner, All Rights Reserved.

# Set the default AWS_REGION so that the s3encrypt gem is happy.
# This value is unfortunately not immediately available in instance metadata.
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

# Decrypt and download the secrets file from the S3 location specified in ~/attributes/default.rb
S3encrypt.getfile(node['s3encrypt']['local_secret_path'], node['s3encrypt']['s3_secret_path'], node['s3encrypt']['s3_bucket'], node['s3encrypt']['encryption_context'])

# Read the decrypted secrets file and add the contents to a local Ruby variable called `file`
file = IO.read(node['s3encrypt']['local_secret_path'])

# Use the JSON library to parse the local `file` variable and convert to a Ruby hash
hash = JSON.parse(file)

# Delete the decrypted secrets file immediately from the filesystem
# Remove secrets from filesystem
execute 'delete-secrets' do
  command "rm -f #{node['s3encrypt']['local_secret_path']}"
  sensitive true
end

# Use the in-memory `hash` variable to inject the secrets into an arbitrary file
#file "#{::Chef::Config['file_cache_path']}/delete_me" do
#  content "#{hash}"
#  sensitive true
#end
