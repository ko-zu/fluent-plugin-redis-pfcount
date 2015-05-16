
module Fluent
  class RedisPfcountOutput < BufferedOutput
    Fluent::Plugin.register_output('redis_pfcount', self)

    # same params with plugin-output-redis
    # https://github.com/yuki24/fluent-plugin-redis
    config_param :host, :string, :default => 'localhost'
    config_param :port, :integer, :default => 6379
    config_param :db_number, :integer, :default => 0

    # or url, unix path
    config_param :url, :string, :default => ''
    config_param :path, :string, :default => ''

    # '*' will be replaced by tag
    config_param :key_prefix, :string, :default => 'pfcount:*:'

    # append date
    config_param :key_with_time, :string, :default => ''

    # append record attribute
    config_param :key_attr, :string, :default => ''

    # record attribute name to distinct
    config_param :distinct_attr, :string
    
    # emit record with new tag and pfadd/pfcount results
    config_param :emit_tag, :string, :default => ''
    config_param :emit_changed, :string, :default => ''
    config_param :emit_pfcount, :string, :default => 'pfcount'
    
    # drop if pfadd did not alter HLL
    config_param :drop_unchanged, :bool, :default => false


    def initialize
      super
      require 'redis'
    end

    def configure(conf)
      super
      @key_prefix_rewrite = @key_prefix.include? '*'
      @emit_tag_rewrite = @emit_tag.include? '*'
    end

    def start
      super
      if not @url.empty?
        @redis = Redis.new(:url => @url)
      elsif not @path.empty?
        @redis = Redis.new(:path => @path, :db => @db_number)
      else
        @redis = Redis.new(:host => @host, :port => @port, :db => @db_number)
      end
      @redis.ping
    end

    def shutdown
      @redis.quit
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      results = []
      @redis.connect unless @redis.connected?

      @redis.pipelined do
        chunk.msgpack_each do |(tag, time, record)|
          key = @key_prefix_rewrite ? @key_prefix.sub('*', tag) : @key_prefix.to_s
          key += Time.at(time).utc.strftime(@key_with_time) unless @key_with_time.empty?
          key += record.fetch(@key_attr, '').to_s unless @key_attr.empty?

          val = record.fetch(@distinct_attr, nil).to_s

          changed = @redis.pfadd(key, val)
          unless @emit_tag.empty?
            results.push [tag, time, record, changed, @emit_pfcount.empty? ? nil : @redis.pfcount(key)]
          end
        end
      end

      unless @emit_tag.empty?
        results.delete_if do |(tag, time, record, changed, pfcount)|
          next if @drop_unchanged and not changed.value
          
          tag = @emit_tag_rewrite ? @emit_tag.sub('*', tag) : @emit_tag

          record[@emit_changed] = changed.value unless @emit_changed.empty?
          record[@emit_pfcount] = pfcount.value unless @emit_pfcount.empty?

          Fluent::Engine.emit(tag, time, record)

          true
        end
      end
    end
  end
end

