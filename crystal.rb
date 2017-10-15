# 已经在标准库中 load 过
# 只需要 require 就可以了
# TCPSocket represents a TCP/IP client socket.
require 'socket'
require 'http/parser'

class Crystal
  # 通过 port 号建立一个 TCPServer socket
  def initialize(port)
    @server = TCPServer.new(port)
  end

  def start
    # loop 一直保持连接
    loop do
      # 服务器端开始接受连接
      socket = @server.accept
      connection = Connection.new(socket)
      connection.process
      # 返回响应之后连接会断开
      # 要保持连接用 loop 块
    end
  end

  class Connection
    def initialize(socket)
      @socket = socket
      @parser = Http::Parser.new(self)
    end

    def process
      # read 1024 bytes
      # 但数据有比 1024 bytes 多的情况
      # 所以保持连接并读数据直到连接关闭或没有数据为止
      until @socket.closed? || @socket.eof?
        data = @socket.readpartial(1024)
        @parser << data
      end
    end

    # 一旦 request 被收到的回调函数
    def on_message_complete
      puts "#{@parser.http_method} #{@parser.request_path}"
      puts "   " + @parser.headers.inspect
      send_response
    end

    # 因为可能有 another one？
    def send_response
      @socket.write "HTTP/1.1 200 OK\r\n"
      # "\r\n" 一般一起用，表示键盘上的回车键
      @socket.write "\r\n"
      @socket.write "hello\n"
      close
    end

    def close
      @socket.close
    end
  end
end

server = Crystal.new(3000)
puts "Plugging crystal into port 3000"
server.start
