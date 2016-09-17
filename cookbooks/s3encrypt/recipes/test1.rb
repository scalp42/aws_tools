chef_gem 's3encrypt' do
  action :install
  compile_time true
end

# Require necessary gems and libraries
require 's3encrypt'

# Decrypt and download the secret file to the server
### THIS IS HAPPENING IN COMPILE
s3encrypt 'Decrypt and Download Secrets' do
  action :nothing
  bucket node['s3encrypt']['s3_bucket']
  context node['s3encrypt']['encryption_context']
  path "#{::Chef::Config['file_cache_path']}/secrets.json"
  remote_path node['s3encrypt']['s3_secret_path']
end.run_action(:download)

# Decrypt JSON secrets file
### THIS IS HAPPENING IN CONVERGE
s3encrypt 'Decrypt JSON Secrets In Memory' do
  action :decrypt
  bucket node['s3encrypt']['s3_bucket']
  context node['s3encrypt']['encryption_context']
  remote_path node['s3encrypt']['s3_secret_path']
#  puts "#{s}"
end


### THIS IS HAPPENING IN COMPILE
puts IO.read("#{::Chef::Config['file_cache_path']}/secrets.json")


#file "#{::Chef::Config['file_cache_path']}/delete_me" do
#  content "#{secrets['user1']}"
#  sensitive true
#end
