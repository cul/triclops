class Triclops::Storage::FileObject < Triclops::Storage::AbstractObject
  attr_reader :path

  def initialize(location_uri)
    super(location_uri)
    # NOTE: Need to decode location URI in order to convert %20 to space,
    # so that Ruby file operation methods can resolve paths.
    @path = Addressable::URI.unencode(URI(location_uri).path)
  end

  def exist?
    File.exist?(self.path)
  end

  def write(&block)
    FileUtils.mkdir_p(File.dirname(self.path))
    File.open(self.path, 'wb', &block)
  end

  def with_file(&block)
    File.open(self.path, 'rb', &block)
  end
end
