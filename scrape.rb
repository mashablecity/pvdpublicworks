#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'builder'
require 'virtus'
require 'chronic'

BASE_URL = "http://providenceri.com/DPW/"

class RssItem
  include Virtus.model

  attribute :title
  attribute :link
  attribute :description
  attribute :pub_date
  attribute :guid
end

class RssFeed
  include Virtus.model

  attribute :title
  attribute :description
  attribute :link
  attribute :items, Array[RssItem]
end

doc = Nokogiri::HTML(open(BASE_URL))

rss_feed = RssFeed.new(
  title: doc.css('title').first.content,
  description: doc.css('.DeptTagline img').first['alt'],
  link: BASE_URL,
)

doc.css('.SideList li a').each do |a|
  # TODO: use e.g. Mechanize to navigate to these links in a more wholesome way.
  link_url = "http://" + URI.parse(BASE_URL).host + a['href']
  sub_doc = Nokogiri::HTML(open(link_url))

  description = sub_doc.css('.content p').map(&:content).reject{|s| s.include? 'Sitemap' }.max_by(&:length)

  pub_date_node = sub_doc.css('.date-display-single').first
  pub_date = Chronic.parse(pub_date_node.content) if pub_date_node

  rss_feed.items << RssItem.new(
    title: a.content,
    link: link_url,
    description: description,
    pub_date: pub_date,
    guid: link_url,
  )
end

xml = Builder::XmlMarkup.new(:target=>STDOUT, :indent=>2)
xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0" do
  xml.channel do
    xml.title rss_feed.title
    xml.description rss_feed.description
    xml.link rss_feed.link

    rss_feed.items.each do |item|
      xml.item do
        xml.title item.title
        xml.link item.link
        xml.description item.description
        xml.pubDate item.pub_date.rfc822 if item.pub_date
        xml.guid item.guid
      end
    end
  end
end
