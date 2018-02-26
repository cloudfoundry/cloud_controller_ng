FROM ruby:2.4.3-stretch

RUN wget https://github.com/google/protobuf/releases/download/v3.5.1/protoc-3.5.1-linux-x86_64.zip
RUN apt-get update && apt-get install unzip
RUN unzip protoc-3.5.1-linux-x86_64.zip
RUN mv bin/protoc /usr/local/bin
RUN mv include/* /usr/local/include
RUN gem install grpc-tools
