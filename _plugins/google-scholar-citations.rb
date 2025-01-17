require "active_support/all"
require "nokogiri"
require "open-uri"

module Helpers
  extend ActiveSupport::NumberHelper
end

module Jekyll
  class GoogleScholarCitationsTag < Liquid::Tag
    Citations = {}

    def initialize(tag_name, params, tokens)
      super
      splitted = params.split(" ").map(&:strip)
      @scholar_id = splitted[0]
      @article_id = splitted[1]
    end

    def render(context)
      # Extract Liquid context variables
      scholar_id = context[@scholar_id.strip]
      article_id = context[@article_id.strip]

      if scholar_id.nil? || article_id.nil?
        puts "Error: scholar_id or article_id is missing!"
        return "N/A"
      end

      # Construct the article URL
      article_url = "https://scholar.google.com/citations?view_op=view_citation&hl=en&user=#{scholar_id}&citation_for_view=#{scholar_id}:#{article_id}"

      begin
        # Check if the citation count is cached
        if Citations[article_id]
          puts "Cache hit for article_id: #{article_id}"
          return Citations[article_id]
        end

        # Add delay to avoid Google blocking
        sleep(rand(3..5))

        # Fetch the article page
        puts "Fetching URL: #{article_url}"
        doc = Nokogiri::HTML(
          URI.open(article_url, "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
        )

        # Attempt to extract the citation count
        citation_count = 0
        cited_by_match = doc.at_css("body")&.text&.match(/Cited by (\d+)/)

        if cited_by_match
          citation_count = cited_by_match[1].to_i
        else
          puts "Cited by data not found on page."
        end

        # Format citation count (e.g., 1.2K, 3M)
        citation_count = Helpers.number_to_human(citation_count, format: "%n%u", precision: 2, units: { thousand: "K", million: "M", billion: "B" })

      rescue OpenURI::HTTPError => e
        # Handle HTTP errors (e.g., 404, 403)
        puts "HTTP Error for #{article_url}: #{e.message}"
        citation_count = "N/A"
      rescue StandardError => e
        # Handle generic errors
        puts "Error fetching citation count for #{article_id}: #{e.class} - #{e.message}"
        citation_count = "N/A"
      end

      # Cache the result and return it
      Citations[article_id] = citation_count
      citation_count
    end
  end
end

Liquid::Template.register_tag("google_scholar_citations", Jekyll::GoogleScholarCitationsTag)
