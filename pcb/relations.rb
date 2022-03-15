#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'pathname'

jsonfile, csvfile = ARGV

name = CSV.table(csvfile).map { |r| [r[:id], r[:name]] }.to_h

jsontxt = Pathname.new(jsonfile).read
json = JSON.parse(jsontxt, symbolize_names: true)

out = json.flat_map do |pep|
  pep[:family].flat_map do |relation, relatives|
    relatives.compact.map do |relative|
      [pep[:id], pep[:name], relation.to_s, relative, name[relative]]
    end
  end
end

puts 'id,name,relationship,relative,relativename'
puts out.sort_by { |row| row.values_at(0,2,3) }.map(&:to_csv)
