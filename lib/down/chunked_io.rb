require "tempfile"

module Down
  class ChunkedIO
    attr_reader :tempfile, :data

    def initialize(options)
      @size     = options.fetch(:size)
      @chunks   = options.fetch(:chunks)
      @on_close = options.fetch(:on_close, ->{})
      @data     = options.fetch(:data, {})
      @tempfile = Tempfile.new("down", binmode: true)

      peek_chunk
    end

    def size
      @size
    end

    def read(length = nil, outbuf = nil)
      download_chunk until enough_downloaded?(length) || download_finished?
      @tempfile.read(length, outbuf)
    end

    def each_chunk
      return enum_for(__method__) if !block_given?
      yield retrieve_chunk until download_finished?
    end

    def eof?
      @tempfile.eof? && download_finished?
    end

    def rewind
      @tempfile.rewind
    end

    def close
      terminate_download
      @tempfile.close!
    end

    private

    def download_chunk
      write(retrieve_chunk)
    end

    def retrieve_chunk
      chunk = @chunks.next
      peek_chunk
      chunk
    end

    def peek_chunk
      @chunks.peek
    rescue StopIteration
      terminate_download
    end

    def enough_downloaded?(length)
      length && (@tempfile.pos + length <= @tempfile.size)
    end

    def download_finished?
      !@on_close
    end

    def terminate_download
      @on_close.call if @on_close
      @on_close = nil
    end

    def write(chunk)
      current_pos = @tempfile.pos
      @tempfile.pos = @tempfile.size
      @tempfile.write(chunk)
      @tempfile.pos = current_pos
    end
  end
end
