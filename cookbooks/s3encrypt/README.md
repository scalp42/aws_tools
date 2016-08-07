# s3encrypt

## Description
The s3encrypt cookbook provides a wrapper for building the [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) RubyGem from source, retrieving a secrets file from S3 that was uploaded using any of the `put_file` methods of the s3encrypt gem, decrypting the secrets file, and making the secrets available to the Chef client for injection into properties files/environment variables, etc.  This is a lightweight method of secrets management that does not require creation of a dedicated secrets server.

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
    - Users must determine the encryption context AND KMS master key used for original encryption prior to any attempts to decrypt the encryption key.  The encrypted encryption key CANNOT be used to decrypt the secrets file without first utilizing KMS to decrypt the encryption key.  This, in essence, provides multi-layer encryption.

**4. Secrets are never stored in GitHub**
  - Local secrets files should be added to .gitignore

**5. Server-side encryption**
  - S3encrypt supports multiple levels of S3 server-side encryption for security-conscious organizations (if the Hamburglar gains physical access to the disk containing your data, he will be foiled by the server-side encryption)

**6. Logs**
  - This cookbook utilizes the `sensitive true` property of native Chef resources to ensure that secrets are not logged by the Chef client either during the original secrets download or during the creation of the new checksum created when the secrets file contents are updated on the target filesystem.  This further ensures that secrets are only ever available in plain text:
  - On the original workstation that was used to upload the secrets (system administrator, file added to .gitignore)
  - In the target properties file(s) where secrets would exist in plain text anyway
  - In environment variables on the target server, if that meets your security standards

## Requirements

### *AWS Configuration*

Your AWS profile must provide permissions for your user account to encrypt/decrypt using KMS as well as reading and writing to an S3 bucket of your choice.  An example IAM policy showing an appropriate configuration is below:

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


### *Platforms*
- As this cookbook facilitates and depends on [the use of a gem](https://github.com/DonMills/ruby-kms-s3-gem) that was solely built for AWS, this cookbook can only be used on AWS instances. This cookbook has been tested on:

- Amazon Linux
- CentOS 6
- CentOS 7
- RHEL 6
- RHEL 7
- Ubuntu 14.04
- Windows 2008R2
- Windows 2012R2

### *Gems*
The following gems are required to upload secret files to S3 using the s3encrypt gem:

* [aws-sdk](https://rubygems.org/gems/aws-sdk) - Provides the API interface between your workstation and your AWS account
* [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) - Provides a library to interact with your [AWS KMS Customer Master Key (CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys) and provided S3 bucket

The following gems are required to download secret files from S3 using the s3encrypt gem:

* [aws-sdk](https://rubygems.org/gems/aws-sdk) - Provides the API interface between your EC2 instance and your AWS account
* [json](https://rubygems.org/gems/json) - Provides a JSON parsing method that allows the Chef client to convert a secrets JSON hash into a Ruby hash for password injection into properties files/environment variables
* [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) - Provides a library to interact with your [AWS KMS Customer Master Key (CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys) and provided S3 bucket


### *Example*
#### *Uploading Secrets*
* Please make sure that the aws-sdk is installed and configured on your system.  The easiest way to verify that things are configured correctly is to run `aws s3 ls`.  You should expect to see your AWS account's S3 buckets in the resulting response.

In order to easily upload secrets to S3, make sure that your `AWS_REGION` environment variable is set.

* Linux/OSX - `export AWS_REGION=us-east-1`
* Windows - `set AWS_REGION=us-east-1`

After the AWS_REGION variable is appropriately set and you are able to list your S3 buckets, you should create your secrets hash as follows:

_secrets.json_
```
{
  "user1": "P@ssw0rd1",
  "user2": "MySuperSecretP@ssw0rdIsB3tt3rThanUrz"
}
```

It is also helpful to create a helper script to call the s3encrypt gem.  The following methods for uploading files to S3 are provided by the gem; use any of the following methods to upload your secrets depending on the level of server-side encryption you prefer on files in your S3 buckets:

* `s3encrypt_putfile()` - Uploads an encrypted file to an S3 bucket of your choice with no server-side encryption
* `s3encrypt_putfilekms()` - Uploads an encrypted file to an S3 bucket of your choice using S3 server-side encryption provided by your KMS master key
* `s3encrypt_putfilesse()` - Uploads an encrypted file to an S3 bucket of your choice using S3 server-side encryption provided by Amazon

The `S3encrypt.putfile()` methods expect several arguments as follows:

1. The filename (including extension) of the file to be encrypted.  The s3encrypt Ruby gem does NOT require this to be a JSON file, but the s3encrypt cookbook expects it to be.
2. The path in S3 to the secrets file.  This must not begin with a forward slash and assumes that the S3 bucket is already created.  Please specify this argument by listing any sub-bucket folders followed by the secrets filename (including extension).
3. The name of your S3 bucket.
4. The value for your encryption context.  The encryption context is entirely arbitrary, but the `getfile()` method of the s3encrypt Gem will expect the same encryption context that you used to upload the secrets.  There is no way to retrieve the secrets unless the same encryption context is provided during the decryption call.
5. The unique identifier for your AWS KMS master key that should be used to generate an encryption key and encrypt your specified files.

_uploadsecrets.rb_
```
require 'aws-sdk'
require 's3encrypt'

S3encrypt.putfile_ssekms("secrets.json", "secrets/secrets.json", "dtashner", "calvin_and_hobbes", "ceb7c49b-e69d-49b3-8866-2b1f97d8fcb0")

#S3encrypt.putfile_ssekms("local_secrets_file", "s3_path_to_secrets_file", "s3_bucket", "encryption_context", "aws_kms_customer_master_key"")
```
Click here to view a quick video displaying how secrets are uploaded to S3.[![asciicast](http://asciinema.org/a/aa25fhuhnpvb7gzrcn3jbiat2.png)](http://asciinema.org/a/aa25fhuhnpvb7gzrcn3jbiat2)

#### *Results*
After succesfully running the `uploadsecrets.rb` script, there should be 2 new files visible in the S3 bucket that you selected:

* secrets.json - The encrypted secrets file containing your hash of secrets
* secrets.json.key - The encrypted private key generated by KMS + the s3encrypt gem, which was used to encrypt your secrets.json file

Click here to view a quick video displaying the results of uploading a secrets file to S3 using S3encrypt. [![asciicast](http://asciinema.org/a/3shl0fmifw48hhqzyuwwp35y4.png)](http://asciinema.org/a/3shl0fmifw48hhqzyuwwp35y4)


After a successful upload, your S3 bucket should have the following items:
[image](https://i.imgur.com/IbNEihB.png)

### *Cookbook Functionality*

#### *Default Attributes*
This Chef cookbook provides a few default attributes to assit the decryption and utilization of secrets files:

_~/attributes/default.rb_
* `default['s3encrypt']['aws_region']` = 'us-east-1'
* `default['s3encrypt']['encryption_context']` = 'calvin_and_hobbes'
* `default['s3encrypt']['local_secret_path']` = "#{::Chef::Config['file_cache_path']}/secrets.json"
* `default['s3encrypt']['s3_secret_path']` = 'secrets/secrets.json'
* `default['s3encrypt']['s3_bucket']` = 'dtashner'

#### *build_s3encrypt Recipe*
Currently, the s3encrypt gem is not available on [RubyGems](https://rubygems.org). Until the gem becomes available, it is necessary to build it from source.  The `s3encrypt::build_s3encrypt` recipe handles this by cloning the source Git repository and building the gem manually.  The gem is then installed, after which point it can be used to decrypt secrets files stored in S3.

#### *default Recipe*
The default recipe of the s3encrypt cookbook guarantees that necessary libraries (aws-sdk, json, s3encrypt) are available to the system, after which the `getfile()` method of the s3encrypt gem is utilized to download a secrets JSON file during the compile phase of the Chef client run.  The JSON file is then parsed by the Ruby interpreter and converted to a Ruby hash.  Once the secrets file is available to the Chef client as a Ruby hash, the key/value pairs of the JSON file are available to the Chef client.  Chef is then able to inject the values of the secrets hash into properties files or inject the secrets as environment variables, depending on the requirements of the client.

_~/recipes/default.rb_
```
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
file '/tmp/secrets' do
  content "#{hash}"
  sensitive true
end
```

# Copyright
Apache 2.0 - Dave Tashner and Don Mills 2016
