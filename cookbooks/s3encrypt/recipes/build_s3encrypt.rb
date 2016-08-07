# We need Git during compile to clone the s3encrypt repository
package 'git' do
  action :nothing
end.run_action(:install)

# Clone the s3encrypt repository during compile
git "#{::Chef::Config['file_cache_path']}/s3encrypt" do
  action :nothing
  repository 'https://github.com/DonMills/ruby-kms-s3-gem.git'
end.run_action(:sync)

# Build the gem during compile
execute 'build_gem' do
  action :nothing
  command 'gem build s3encrypt.gemspec'
  cwd "#{::Chef::Config['file_cache_path']}/s3encrypt"
end.run_action(:run)

# Install gem during compile
chef_gem 's3encrypt' do
  compile_time true
  source "#{::Chef::Config['file_cache_path']}/s3encrypt/s3encrypt-0.1.6.gem"
end
