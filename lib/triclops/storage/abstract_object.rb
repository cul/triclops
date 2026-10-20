class Triclops::Storage::AbstractObject
  attr_reader :scheme, :location_uri

  def initialize(location_uri)
    @location_uri = location_uri
    @scheme = URI(location_uri).scheme

    return unless self.instance_of?(Triclops::Storage::AbstractObject)

    raise NotImplementedError, "The #{self.class.name} class cannot be instantiated.  "\
          'You can only instantiate subclasses like Triclops::FileCacheObject'
  end

  def exist? = raise(NotImplementedError)
  def write = raise(NotImplementedError)
  def with_file = raise(NotImplementedError)
end
