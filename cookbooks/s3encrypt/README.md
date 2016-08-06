# s3encrypt

## Description
The s3encrypt cookbook provides a wrapper for building the [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) RubyGem from source, retrieving a secrets file from S3 that was uploaded using any of the `put_file` methods of the s3encrypt gem, decrypting the secrets file, and making the secrets available to the Chef client for injection into properties files/environment variables, etc.  This is a lightweight method of secrets management that does not require creation of a dedicated secrets server.

## Requirements
As this cookbook facilitates the use of a gem that was solely built for AWS, this cookbook can only be used on AWS instances.  The [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) gem should be used to first upload a JSON file containing a hash of secrets into an S3 location of your choice.

### *Gems*
The following gems are required to upload secret files to S3 using the s3encrypt gem:

* aws-sdk - Provides the API interface between your workstation and your AWS account
* s3encrypt - Provides a library to interact with your [AWS KMS Customer Master Key (CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys) and provided S3 bucket

The following gems are required to download secret files from S3 using the s3encrypt gem:

* [aws-sdk](https://rubygems.org/gems/aws-sdk) - Provides the API interface between your EC2 instance and your AWS account
* [json](https://rubygems.org/gems/json) - Provides a JSON parsing method that allows the Chef client to convert a secrets JSON hash into a Ruby hash for password injection into properties files/environment variables
* [s3encrypt](https://github.com/DonMills/ruby-kms-s3-gem) - Provides a library to interact with your [AWS KMS Customer Master Key (CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys) and provided S3 bucket


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

_uploadsecrets.rb_
```
require 'aws-sdk'
require 's3encrypt'

S3encrypt.putfile_ssekms("secrets.json", "secrets/secrets.json", "dtashner", "calvin_and_hobbes", "ceb7c49b-e69d-49b3-8866-2b1f97d8fcb0")

#S3encrypt.putfile_ssekms("local_secrets_file", "s3_path_to_secrets_file", "s3_bucket", "encryption_context", "aws_kms_customer_master_key"")
```

[Please click here](http://asciinema.org/a/aa25fhuhnpvb7gzrcn3jbiat2) to view a quick video displaying how secrets are uploaded to S3.

#### *Results*
After succesfully running the `uploadsecrets.rb` script, there should be 2 new files visible in the S3 bucket that you selected:

* secrets.json - The encrypted secrets file containing your hash of secrets
* secrets.json.key - The encrypted private key generated by KMS + the s3encrypt gem, which was used to encrypt your secrets.json file

[image](https://i.imgur.com/IbNEihB.png)
