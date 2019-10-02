# DnsApi is the top level DnsApi module
module DnsApi
  VERSION_FILE = File.dirname(__FILE__) + '/../config/version'
  VERSION = File.readlines(VERSION_FILE).first.strip unless defined? VERSION
end
