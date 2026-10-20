module Triclops::Storage
  FILE_SCHEME = 'file'.freeze # file://
  S3_SCHEME = 's3'.freeze # s3://
  STORAGE_SCHEMES = [FILE_SCHEME, S3_SCHEME].freeze

  def self.storage_object_for(location_uri)
    uri = URI(location_uri)

    case uri.scheme
    when FILE_SCHEME
      Triclops::Storage::FileObject.new(location_uri)
    when S3_SCHEME
      Triclops::Storage::S3Object.new(location_uri)
    else
      raise ArgumentError, "Unsupported URI scheme: #{location_uri}"
    end
  end
end
