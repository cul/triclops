module Triclops
  # A class that keeps track of recently accessed resource ids so that they can
  # be retrieved in batch and persisted long-term to the Resource persistence layer.
  class ResourceAccessStatCache
    # Singleton pattern Triclops::ResourceAccessStatCache instance for this class.
    def self.instance
      @instance ||= new(
        Redis.new(
          host: REDIS_CONFIG[:host],
          port: REDIS_CONFIG[:port],
          password: REDIS_CONFIG[:password],
          thread_safe: true
        ),
        "#{Rails.application.class.module_parent_name}:#{Rails.env}:raster_access_entries".freeze
      )
    end

    # Initialize a new Triclops::ResourceAccessStatCache object.
    # @param redis [Redis] A Redis connection instance.
    # @param cache_list_key [String] A key to use for the cache list entry.
    def initialize(redis, cache_list_key)
      @redis = redis
      @cache_list_key = cache_list_key
    end

    # Adds the given identifier to the set of cached identifiers. Multiple calls
    # with the same identifier will only result in the identifier being added once.
    # @param identifier [String] An identifier
    def add(identifier)
      @redis.sadd?(@cache_list_key, identifier)
    end

    # Returns all cached identifiers (with no guarantees about order).
    # @return [Array<String>] An array of string identifiers.
    def all
      @redis.smembers(@cache_list_key)
    end

    # Clears all cached identifiers.
    def clear
      @redis.del(@cache_list_key)
    end
  end
end
