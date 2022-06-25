#!/bin/env ruby
# frozen_string_literal: true

require 'every_politician_scraper/scraper_data'
require 'pry'

class MemberList
  class Members
    decorator RemoveReferences
    decorator UnspanAllTables
    decorator WikidataIdsDecorator::Links

    def member_container
      noko.xpath("//table[.//th[contains(.,'Fonction')]]//tr[td]")
    end
  end

  class Member
    field :item do
      name_node.attr('wikidata')
    end

    field :itemLabel do
      name_node.text.tidy
    end

    field :position do
    end

    field :positionLabel do
      tds[1].text.tidy
    end

    field :startDate do
      '2021-04-26'
    end

    field :endDate do
    end

    private

    def tds
      noko.css('td')
    end

    def name_node
      tds[2].css('a').first
    end
  end
end

url = ARGV.first
puts EveryPoliticianScraper::ScraperData.new(url).csv
