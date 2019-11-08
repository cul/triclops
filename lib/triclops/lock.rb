module Triclops
  class Lock
    # Singleton pattern Triclops::Lock instance for this class.
    def self.instance
      @instance ||= new(
        Redis.new(
          host: REDIS_CONFIG[:host],
          port: REDIS_CONFIG[:port],
          password: REDIS_CONFIG[:password],
          thread_safe: true
        ),
        TRICLOPS[:lock][:lock_timeout],
        TRICLOPS[:lock][:retry_count],
        TRICLOPS[:lock][:retry_delay],
        "#{Rails.application.class.module_parent_name}:#{Rails.env}:lock".freeze
      )
    end

    # Initialize a new Triclops::Lock object.
    # @param redis [Redis] A Redis connection instance.
    # @param key_prefix [String] A string prefix concatenated with lock keys,
    #   in case you're pointing multiple Triclops applications at the same
    #   redis instance and want to either isolate lock keys (use different prefixes)
    #   or share lock keys (use the same prefix) between the applications.
    # @param lock_timeout [FixNum]
    #   Number of seconds before a lock times out.
    # @param retry_count [FixNum]
    #   Number of times to retry establishing a lock when blocked.
    # @param retry_delay [FixNum]
    #   Number of seconds to wait between lock retry attempts.
    def initialize(redis, lock_timeout, retry_count, retry_delay, key_prefix = '')
      @lock_manager = Redlock::Client.new(
        [redis],
        {
          retry_count: retry_count,
          retry_delay: (retry_delay * 1000).to_i, # convert to milliseconds
          retry_jitter: 50, # milliseconds
          redis_timeout: 0.1 # seconds
        }
      )
      @key_prefix = key_prefix
      @lock_timeout = lock_timeout
    end

    # Establish a blocking lock for the given key (or wait for an existing
    # blocking lock to be released) and then yield to a block of code to execute.
    # @param key [String] A key to use for this lock.
    def with_blocking_lock(key)
      @lock_manager.lock!("#{@key_prefix}#{key}", (@lock_timeout * 1000).to_i) do
        yield
      end
    end
  end
end
