class Triclops::Storage::S3Object < Triclops::Storage::AbstractObject
  attr_reader :bucket_name, :key

  def initialize(location_uri)
    super(location_uri)

    uri = URI(location_uri)
    @bucket_name = uri.host
    @key = uri.path.gsub(%r{^/}, '') # Remove leading slash if present
  end

  def file_extension
    File.extname(self.key)
  end

  def s3_object(reload: false)
    @s3_object = nil if reload
    @s3_object ||= Aws::S3::Object.new(self.bucket_name, self.key, { client: S3_CLIENT })
  end

  def exist?
    s3_object.exists?
  end

  def write
    upload_result = nil
    Triclops::FileHelper.working_directory_temp_file('for-s3-upload', self.file_extension) do |tempfile|
      # yield the tempfile so the caller can write to it
      yield tempfile
      # close the file to ensure that all bytes have been flushed to disk
      tempfile.close

      # # After the yield is complete and all bytes have been written to the file, upload the file
      transfer_manager = Aws::S3::TransferManager.new(client: S3_CLIENT)
      upload_result = transfer_manager.upload_file(
        tempfile.path,
        bucket: s3_object.bucket_name,
        key: s3_object.key,
        # NOTE: Supplying a checksum_algorithm option with value 'CRC32C' will make the AWS SDK
        # automatically calculate a local CRC32C checksum before sending the file to S3 (for both
        # multipart and single part uploads).  The upload will fail if the corresponding checksum
        # calculated by S3 does not match.
        checksum_algorithm: 'CRC32C',
        content_type: BestType.mime_type.for_file_name(tempfile.path)
      )
    end
    return if upload_result

    raise Triclops::Exceptions::S3UploadError, 'Error during file upload. Did not receive confirmation from AWS.'
  end

  def with_file
    Triclops::FileHelper.working_directory_temp_file('s3-download', self.file_extension) do |tempfile|
      S3_CLIENT.get_object({ bucket: self.bucket_name, key: self.key, response_target: tempfile.path })
      yield tempfile
    rescue Aws::S3::Errors::NoSuchKey
      raise "Could not find source file: #{location_uri}"
    end
  end
end
