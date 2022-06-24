#!/bin/bash

cd $(dirname $0)

# curl https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/data/Congo-Kinshasa/Assembly/term-2012.csv | qsv select wikidata,name,wikidata_group,group,wikidata_area,area,start_date,end_date,gender | sed -e 's/Q1740056/Q1425821/g' | qsv rename item,itemLabel,party,partyLabel,area,areaLabel,startDate,endDate,gender > scraped.csv

wd sparql -f csv wikidata.js | sed -e 's/T00:00:00Z//g' -e 's#http://www.wikidata.org/entity/##g' | qsv dedup -s psid | qsv sort -s itemLabel,startDate > wikidata.csv
bundle exec ruby diff.rb | tee diff.csv

cd ~-
