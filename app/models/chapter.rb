class Chapter < ActiveRecord::Base

  COMMENT_MAX_CHARS = 2000

  has_many :readings
  has_many :users, through: :readings
  has_many :bookfrags, primary_key: :book_id, foreign_key: :book_id
  has_many :comments, as: :commentable, dependent: :destroy

  scope :excluding_ids, lambda { |ids|
    ids = [ids].flatten
    where("chapters.id not in (?)", ids) if ids.any?
  }

  class << self
    def most_read
      readings = Reading.where('created_at >= ?', 24.hours.ago).group(:chapter).count
      readings.key(readings.values.max)
    end

    def search(query)
      fragment, chapters = parse_query(query)

      # First search by fragment
      bookfrag = Bookfrag.where("upper(:query) like upper(fragment) || '%'",
                                query: fragment).first
      matches = where(book_id: bookfrag.try(:book_id))
      .where(chapter: chapters)

      # If nothing found, then search by Chapter name
      unless matches.length > 0 # Using .any? here causes an extra query
        matches = where("upper(name) like upper(:query)", query: "#{fragment}")
        .where(chapter: chapters)
      end

      matches
    end

    def parse_query(query)
      regex = /^\s*([0-9]?\s*[a-zA-Z]+)\.?\s*([0-9]+)(?:\s*(?:-|..)[^0-9]*([0-9]+))?/
      match = query.match(regex)
      if match
        if match[3]
          chapters = (match[2]..match[3]).to_a
        else
          chapters = [ match[2] ]
        end
        [ match[1].gsub(/ /, ""), chapters ]
      else
        [nil, nil]
      end
    end
  end

  def title
    "#{name} #{chapter}"
  end
end
