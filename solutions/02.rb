class Song
  attr_accessor :name, :artist, :genre, :subgenre, :tags

  def initialize(name, artist, genre, subgenre, tags)
    @name = name
    @artist = artist
    @genre = genre
    @subgenre = subgenre
    @tags = tags
  end
  
  def match_criteria?(criteria)
    criteria.all? do |criterion, value|
      case criterion
        when :name then name == value
        when :artist then artist == value
        when :filter then value.call(self)
        when :tags then match_tag?(value)
      end
    end
  end

  def match_tag?(value)
    Array(value).all? do |tag| 
      tag.end_with?('!') ^ tags.include?(tag.chomp '!')
    end
  end
end

class Collection
  
  def initialize(song_as_string, artist_tags)
    @songs = song_as_string.lines.map { |song| song.split(".").map(&:strip) }
    @songs = @songs.map do |name, artist, genres_string, tags_string|
      genre, subgenre = genres_string.split(",").map(&:strip)
      tags = artist_tags.fetch(artist, [])
      tags += [genre, subgenre].compact.map(&:downcase)
      tags += tags_string.split(",").map(&:strip) if tags_string
      
      Song.new(name, artist, genre, subgenre, tags)
    end
  end
  
  def find(criteria)
    @songs.select { |song| song.match_criteria? criteria }
  end
end