# 已经在标准库中 load 过
# 只需要 require 就可以了
# TCPSocket represents a TCP/IP client socket.
require 'socket'

class Crystal
  # 通过 port 号建立一个 TCPServer socket
  def initialize(port)
    @server = TCPServer.new(port)
  end

  def start
    loop do
      # 开始接受连接
      socket = @server.accept
      # read 1024 bytes
      data = socket.readpartial(1024)
      puts data
      socket.write "HTTP/1.1 200 OK\r\n"
      # "\r\n" 一般一起用，表示键盘上的回车键
      socket.write "\r\n"
      socket.write "hello\n"

      socket.close
    end
  end
end

server = Crystal.new(3000)
puts "Plugging crystal into port 3000"
server.start
