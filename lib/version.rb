# DnsApi is the top level DnsApi module
module DnsApi
  VERSION_FILE = format('%<file>s%<path>s', file: File.dirname(__FILE__), path: '/../config/version')
  VERSION = File.readlines(VERSION_FILE).first.strip unless defined? VERSION
end
