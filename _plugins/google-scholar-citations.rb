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
      # Resolve variables from Liquid context
      article_id = context[@article_id.strip]
      scholar_id = context[@scholar_id.strip]

      # Construct the article URL
      article_url = "https://scholar.google.com/citations?view_op=view_citation&hl=en&user=#{scholar_id}&citation_for_view=#{scholar_id}:#{article_id}"

      begin
        # Check if the citation count is already cached
        if Citations[article_id]
          return Citations[article_id]
        end

        # Sleep to avoid triggering anti-scraping measures
        sleep(rand(1.5..3.5))

        # Fetch the article page with a realistic User-Agent
        doc = Nokogiri::HTML(
          URI.open(article_url, "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
        )

        # Extract citation count from the HTML
        citation_count = 0
        cited_by_text = doc.text.match(/Cited by (\d+[,\d]*)/)

        if cited_by_text
          citation_count = cited_by_text[1].gsub(",", "").to_i
        end

        # Format the citation count (e.g., 1.2K, 3M)
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

      # Cache the citation count to reduce requests
      Citations[article_id] = citation_count

      # Return the formatted citation count
      return "#{citation_count}"
    end
  end
end

Liquid::Template.register_tag("google_scholar_citations", Jekyll::GoogleScholarCitationsTag)

