# frozen_string_literal: true

module Triclops
  module FileHelper
    # Creates a Tempfile in the application's "working directory" with a random name and optional
    # prefix and suffix.  If a block is given, this method yields the Tempfile object and
    # immediately deletes the file after the block completes.  If no block is given, the tempfile
    # is returned and not immediately deleted, but remember that this is an actual Ruby Tempfile
    # and the Tempfile might be deleted as soon as Ruby garbage collection runs if there are no
    # longer any references to its variable.  Tempfile deletion timing can be unpredictable, so
    # it's always best to explicitly delete a tempfile as soon as you're done with it.
    def self.working_directory_temp_file(prefix = '', suffix = '', binmode: true)
      file = Tempfile.new([prefix, suffix], TRICLOPS[:tmp_directory], binmode: binmode)
      yield file if block_given?
      file
    ensure
      # Close and unlink the tempfile
      file&.close! if block_given?
    end

    # The method below is commented out because it's not currently in use, but it might be useful later.
    #
    # # Creates a temporary directory in the working directory with a random name and optional suffix,
    # # yields the Dir object and automatically deletes the directory after the passed-in block
    # # completes.
    # def self.working_directory_temp_dir(suffix)
    #   # This method leverages existing temp file functionality to avoid name collisions.
    #   working_directory_temp_file('', '') do |temp_file|
    #     dir_path = "#{temp_file.path}-dir-#{suffix}"
    #     FileUtils.mkdir(dir_path)
    #     dir = Dir.new(dir_path)
    #     yield dir if block_given?
    #   ensure
    #     # Delete the temp directory
    #     FileUtils.rm_rf(dir_path) if block_given?
    #   end
    # end
  end
end
