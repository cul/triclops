module Triclops
  module Exceptions
    class TriclopsError < StandardError; end

    class RasterExists < TriclopsError; end
  end
end
