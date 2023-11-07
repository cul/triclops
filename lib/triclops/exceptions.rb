module Triclops
  module Exceptions
    class TriclopsError < StandardError; end

    class RasterExists < TriclopsError; end
    class MissingBaseImageDependencyException < TriclopsError; end
  end
end
