module Ready
  class Configuration < Struct.new(:record, :compare, :files)
    alias_method :record?, :record
    alias_method :compare?, :compare

    def self.parse_options(argv)
      argv = argv.dup

      record = false
      compare = false

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

        opts.on("--record", "Record the benchmark times") do
          record = true
        end

        opts.on("--compare", "Compare the benchmarks against the last saved run") do
          compare = true
        end
      end

      begin
        parser.parse!(argv)
      rescue OptionParser::InvalidOption => e
        $stderr.puts e
        usage(parser)
      end

      usage(parser) unless record || compare

      files = argv
      new(record, compare, files)
    end

    def self.usage(parser)
      $stderr.puts parser
      exit 1
    end
  end
end
