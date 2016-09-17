resource_name :s3encrypt

property :bucket, String
property :context, String
property :path, String
property :region, String, default: 'us-east-1'
property :remote_path, String

action :download do
  log "Attempting to use #{region} as default region..."
  ENV['AWS_REGION'] = "#{region}"
  log "Downloading decrypted secrets from S3"
  s = S3encrypt.getfile(
    "#{path}",
    "#{remote_path}",
    "#{bucket}",
    "#{context}"
  )
  log "Secrets downloaded."
end

action :decrypt do
  log "Attempting to use #{region} as default region..."
  ENV['AWS_REGION'] = "#{region}"
  log "Decrypting secrets from S3"
  s = S3encrypt.getfile_as_json(
    "#{remote_path}",
    "#{bucket}",
    "#{context}"
  )
  log "Secrets decrypted: #{s}"
end
