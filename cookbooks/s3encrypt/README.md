# s3encrypt

## Table of Contents
1. [Description](#description)
2. [Why?](#why)
3. [About The Gem](#about-the-gem)
4. [Requirements](#requirements)
5. [Platforms](#platforms)
6. [Downloading Secrets](#downloading-secrets)
7. [Example](#example)

## Description
The s3encrypt cookbook provides a wrapper for building the [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) RubyGem from source, retrieving a secrets file from S3 that was uploaded using any of the `put_file` methods of the s3encrypt gem, decrypting the secrets file, and making the secrets available to the Chef client for injection into properties files/environment variables, etc.  In short, this is a lightweight method of secrets management that allows Chef and AWS to do the heavy lifting for you, while simultaneously not requiring creation, maintenance, or patching of a dedicated secrets server.

## Why?
Why would we do this? Why should we use a custom Ruby Gem to handle the encryption of secrets when great tools like [Hashicorp's Vault](https://www.vaultproject.io/), [Chef Vault](https://blog.chef.io/2016/01/21/chef-vault-what-is-it-and-what-can-it-do-for-you/), and others already exist on the market?  Let's see...

**1. Vault and Chef Vault require extra servers to run.**
  - Hashicorp Vault requires a server/client relationship, which will necessitate the creation/patching/management of your own Vault server
  - Chef Vault requires Chef Server, which many companies choose to run without. Even if you use Chef Server, Chef Vault uses data bags, which are fugly.

**2. S3encrypt requires no server**
  - Since s3encrypt utilizes libraries to call AWS KMS for encryption and decryption of secrets files, there is no reliance on a tertiary server solely to host s3encrypt functions.

**3. S3encrypt protects against internal attacks**
  - S3encrypt is reasonably good at securing secrets even within an organization where all employees have basic access to S3
  - An encryption context and S3 master key are required before any decryption activities can succeed
  - Users must determine the encryption context AND have permission to the decrypt function in KMS for the master key used for original encryption of the file prior to any attempts to decrypt the encryption key.  The encrypted encryption key CANNOT be used to decrypt the secrets file without first utilizing KMS to decrypt the encryption key.  This, in essence, provides multi-layer encryption, as KMS will not decrypt the encrypted encryption key without first verifying the encryption context.  Make sense?

**4. Secrets are never stored in GitHub**
  - Local secrets files and upload scripts should be added to .gitignore

**5. Secrets are never stored on Chef Server**
  - If you use Chef Server, this method avoids storing passwords as Chef attributes, which will ultimately end up visible on the Chef server in the node object information for each node.  Instead, this method uses in-memory Ruby variables that are destroyed at the termination of each chef-client run.

**6. Server-side encryption**
  - S3encrypt supports multiple levels of S3 server-side encryption for security-conscious organizations (if the Hamburglar gains physical access to the Amazon data center containing your data, he will be foiled by server-side encryption)

**7. Logs**
  - This cookbook utilizes the `sensitive true` property of native Chef resources to ensure that secrets are not logged by the Chef client either during the original secrets download or during any write operations to the secrets file when Chef downloads and creates the file.  This further ensures that secrets are only ever available in plain text:
  - On the original workstation that was used to upload the secrets (a system administrator may control this workflow; file added to .gitignore)
  - In the target properties file(s) where secrets would exist in plain text anyway
  - In environment variables on the target server, if that meets your security standards

## About The Gem

The following methods for uploading files to S3 are provided by the [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) gem; use any of the following methods to upload your secrets depending on the level of server-side encryption you prefer on files in your S3 buckets:

   * `s3encrypt_putfile()` - Uploads an encrypted file to an S3 bucket of your choice with no server-side encryption
   * `s3encrypt_putfilekms()` - Uploads an encrypted file to an S3 bucket of your choice using S3 server-side encryption provided by your KMS master key
   * `s3encrypt_putfilesse()` - Uploads an encrypted file to an S3 bucket of your choice using S3 server-side encryption provided by Amazon

The `S3encrypt.putfile()` methods expect several arguments as follows:

   1. The filename (including extension) of the file to be encrypted.  The s3encrypt Ruby gem does NOT require this to be a JSON file, but the s3encrypt cookbook expects it to be.
   2. The path in S3 to the secrets file.  This must not begin with a forward slash and assumes that the S3 bucket is already created.  Please specify this argument by listing any sub-bucket folders followed by the secrets filename (including extension).
   3. The name of your S3 bucket.
   4. The value for your encryption context.  The encryption context is entirely arbitrary, but the `getfile()` method of the s3encrypt Gem will expect the same encryption context that you used to upload the secrets.  There is no way to retrieve the secrets unless the same encryption context is provided during the decryption call.
   5. The unique identifier for your AWS KMS master key that should be used to generate an encryption key and encrypt your specified files.


The following method for downloading and decrypting files is provided by the s3encrypt gem.
   * `S3encrypt.getfile()` - Decrypts and downloads an encrypted file from an S3 bucket of your choice

The `S3encrypt.getfile()` method expects several arguments as follows:

   1. The filename (including extension) of the file to be decrypted.  The s3encrypt Ruby gem does NOT require this to be a JSON file, but the s3encrypt cookbook expects it to be.
   2. The path in S3 to the secrets file.  This must not begin with a forward slash and assumes that the secrets file already exists in the given path.  Please specify this argument by listing any sub-bucket folders followed by the secrets filename (including extension).
   3. The name of your S3 bucket.
   4. The value for your encryption context.  The encryption context is entirely arbitrary, but the `getfile()` method of the s3encrypt Gem will expect the same encryption context that you used to upload the secrets with the `putfile()` method.  There is no way to retrieve the secrets unless the same encryption context is provided during the decryption call.


## Requirements

### *AWS Configuration*

Your local AWS profile must provide permissions for your user account to encrypt/decrypt using KMS as well as reading and writing to an S3 bucket of your choice.  An example IAM policy showing an appropriate configuration is below:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateAlias",
        "kms:CreateKey",
        "kms:DeleteAlias",
        "kms:Describe*",
        "kms:GenerateRandom",
        "kms:Get*",
        "kms:List*",
        "iam:ListGroups",
        "iam:ListRoles",
        "iam:ListUsers"
      ],
      "Resource": "*"
    }
  ]
}
```

Your AWS account must have an AWS KMS Customer Master Key created and your user profile should have permissions to utilize the CMK to encrypt and decrypt files.

Any servers that need to access your secret files through the Chef cookbook must have an associated IAM profile with policies granting the ability to decrypt through KMS and read from S3.

### *Gems*
The following gems are required to upload secret files to S3 using the s3encrypt gem:

* [aws-sdk](https://rubygems.org/gems/aws-sdk) - Provides the API interface between your workstation and your AWS account
* [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) - Provides a library to interact with your [AWS KMS Customer Master Key (CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys) and provided S3 bucket

The following gems are required to download secret files from S3 using the s3encrypt gem:

* [aws-sdk](https://rubygems.org/gems/aws-sdk) - Provides the API interface between your EC2 instance and your AWS account
* [json](https://rubygems.org/gems/json) - Provides a JSON parsing method that allows the Chef client to convert a secrets JSON hash into a Ruby hash for password injection into properties files/environment variables
* [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) - Provides a library to interact with your [AWS KMS Customer Master Key (CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys) and provided S3 bucket


### *Packages*
Git (for building s3encrypt from source) and the chef-client should be available on the target server or workstation where the secrets will be utilized.  This cookbook was tested on chef-client 12.12, but is known to work on chef-client versions as old as 12.3.

### *Helper Script*
It is easiest to create a helper script to call the s3encrypt gem. Your AWS credentials should be configured on your local workstation prior to running this script.

_uploadsecrets.rb_
```
require 'aws-sdk'
require 's3encrypt'

S3encrypt.putfile_ssekms("secrets.json", "secrets/secrets.json", "dtashner", "calvin_and_hobbes", "ceb7c49b-e69d-49b3-8866-2b1f97d8fcb0")

#S3encrypt.putfile_ssekms("local_secrets_file", "s3_path_to_secrets_file", "s3_bucket", "encryption_context", "aws_kms_customer_master_key"")
```


## Platforms
- As this cookbook facilitates and depends on [the use of a gem](https://github.com/DonMills/ruby-kms-s3-gem) that was solely built for AWS, this cookbook can only be used on AWS instances. This cookbook has been tested on:

- Amazon Linux
- CentOS 6
- CentOS 7
- RHEL 6
- RHEL 7
- Ubuntu 14.04
- Windows 2008R2
- Windows 2012R2


## Downloading Secrets

### Cookbook Functionality

#### Attributes
This Chef cookbook provides a few default attributes to assist in the decryption and utilization of secrets files, including passwords.

##### *Required Attribute Overrides*
You must provide values for the following default attributes in your own custom cookbook, wrapper cookbook, environment, or role in order for the `s3encrypt` recipes to operate correctly:
* `default['s3encrypt']['encryption_context'] = nil`
* `default['s3encrypt']['s3_secret_path'] = nil`
* `default['s3encrypt']['s3_bucket'] = nil`

_~/attributes/default.rb_
```
default['s3encrypt']['aws_region'] = 'us-east-1'
default['s3encrypt']['encryption_context'] = 'calvin_and_hobbes'
default['s3encrypt']['local_secret_path'] = "#{::Chef::Config['file_cache_path']}/secrets.json"
default['s3encrypt']['s3_secret_path'] = 'secrets/secrets.json'
default['s3encrypt']['s3_bucket'] = 'dtashner'
```


#### Recipes
##### *build_s3encrypt Recipe*
Currently, the s3encrypt gem is not available on [RubyGems](https://rubygems.org). Until the gem becomes available, it is necessary to build it from source.  The `s3encrypt::build_s3encrypt` recipe handles this by cloning the source Git repository and building the gem using the `gem build [gemname].gemspec` command.  The gem is then installed, after which point it can be used to decrypt secrets files stored in S3.


 *build_s3encrypt.rb*
```
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

```

##### *default Recipe*
The default recipe of the s3encrypt cookbook guarantees that necessary libraries (aws-sdk, json, s3encrypt) are available to the Chef client, after which the `getfile()` method of the s3encrypt gem is utilized to download a previously encrypted file during the compile phase of the Chef client run (this cookbook is opinionated and expects a JSON file). The JSON file is then parsed by the Ruby interpreter and converted to a Ruby hash.  Once the secrets file is available to the Chef client as a Ruby hash, the key/value pairs of the JSON file are available to the Chef client.  Chef is then able to inject the values from the secrets hash into properties files or inject the secrets as environment variables, depending on the requirements of the server/application.

It is important to note that the secrets file is intentionally downloaded, converted to a hash, and deleted during the compile phase of the Chef client run.  This design ensures that the password hash is available to the Chef client during the duration of the Chef client run only, and the password hash is removed from memory when the Chef client process is terminated.

_~/recipes/default.rb_
```
# Cookbook Name:: s3encrypt
# Recipe:: default
# Copyright (c) 2016 Dave Tashner

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
file "#{::Chef::Config['file_cache_path']}/delete_me" do
  content "#{hash}"
  sensitive true
end
```

## Example

### Uploading Secrets
1. Please make sure that the aws-sdk is installed and configured on your system.  The easiest way to verify that things are configured correctly is to run `aws s3 ls`.  You should expect to see your AWS account's S3 buckets in the resulting response.

2. In order to easily upload secrets to S3, make sure that your `AWS_REGION` environment variable is set.

  * Linux/OSX - `export AWS_REGION=us-east-1`
  * Windows - `set AWS_REGION=us-east-1`

3. After the AWS_REGION variable is appropriately set and you are able to list your S3 buckets, you should create your secrets hash as follows:

   _secrets.json_
   ```
   {
     "user1pwd": "P@ssw0rd1",
     "user2pwd": "MySuperSecretP@ssw0rdIsB3tt3rThanUrz"
   }
   ```

4. With your secrets file created, create the helper script:

   _uploadsecrets.rb_
   ```
   require 'aws-sdk'
   require 's3encrypt'

   S3encrypt.putfile_ssekms("secrets.json", "secrets/secrets.json", "dtashner", "calvin_and_hobbes", "ceb7c49b-e69d-49b3-8866-2b1f97d8fcb0")

   #S3encrypt.putfile_ssekms("local_secrets_file", "s3_path_to_secrets_file", "s3_bucket", "encryption_context", "aws_kms_customer_master_key")
   ```

5. With the helper script created, upload the secrets file to S3:

   ```
   $ ruby upload_secrets.rb
   $

   ```

   Click here to view a quick video displaying how secrets are uploaded to S3.[![asciicast](http://asciinema.org/a/aa25fhuhnpvb7gzrcn3jbiat2.png)](http://asciinema.org/a/aa25fhuhnpvb7gzrcn3jbiat2)

6. Results:
 After succesfully running the `uploadsecrets.rb` script, there should be 2 new files visible in the S3 bucket that you selected:

   * secrets.json - The encrypted secrets file containing your hash of secrets
   * secrets.json.key - The encrypted private key generated by KMS + the s3encrypt gem, which was used to encrypt your secrets.json file

Click here to view a quick video displaying the results of uploading a secrets file to S3 using S3encrypt. [![asciicast](http://asciinema.org/a/3shl0fmifw48hhqzyuwwp35y4.png)](http://asciinema.org/a/3shl0fmifw48hhqzyuwwp35y4)


After a successful upload, your S3 bucket should have the following items:
![image](https://i.imgur.com/IbNEihB.png)

### Downloading Secrets

1. Include the `s3encrypt::default` recipe in your node's run_list and provide values for the following attributes:

   ```
   default['s3encrypt']['encryption_context'] = 'calvin_and_hobbes'
   default['s3encrypt']['s3_secret_path'] = 'secrets/secrets.json'
   default['s3encrypt']['s3_bucket'] = 'dtashner'
   ```

2. Use the Chef [template resource](https://docs.chef.io/resource_template.html) to inject the sensitive password from the Ruby hash into the properties file:

  _~/cookbooks/your_cookbook/templates/default/confluence.cfg.xml.erb_

   ```
  <Resource
         name="jdbc/confluence"
         auth="Container"
         type="javax.sql.DataSource"
         driverClassName="oracle.jdbc.OracleDriver"
         url="jdbc:oracle:thin:@hostname:port:sid"
         username="user1"
         password=<%= @user2pwd %>
         connectionProperties="SetBigStringTryClob=true"
		 accessToUnderlyingConnectionAllowed="true"
         maxTotal="60"
         maxIdle="20"
         maxWaitMillis="10000"
   />
   ```

  _yourrecipe.rb_
   ```
   template "#{ENV['CONFLUENCE_HOME']}/confluence.cfg.xml" do
    action :create
    sensitive true
    variables({
      :user1pwd => hash['user2pwd']
      }
    )
   end
   ```

 3. Results

    ```
    $ cd ENV['CONFLUENCE_HOME']
    $ pwd
      ~/confluence/conf.d/
    $ cat ./confluence.cfg.xml

    <Resource
           name="jdbc/confluence"
           auth="Container"
           type="javax.sql.DataSource"
           driverClassName="oracle.jdbc.OracleDriver"
           url="jdbc:oracle:thin:@hostname:port:sid"
           username="user2"
           password="MySuperSecretP@ssw0rdIsB3tt3rThanUrz"
           connectionProperties="SetBigStringTryClob=true"
       accessToUnderlyingConnectionAllowed="true"
           maxTotal="60"
           maxIdle="20"
           maxWaitMillis="10000"
     />
    ```

# Copyright
Apache 2.0 - Dave Tashner and Don Mills 2016
