module Triclops
  module Exceptions
    class TriclopsError < StandardError; end

    class RasterExists < TriclopsError; end
    class MissingBaseImageDependencyException < TriclopsError; end
    class UnknownBaseType < TriclopsError; end
    class MissingWidthOrHeightInformation < TriclopsError; end
  end
end
