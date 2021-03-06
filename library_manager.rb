require 'active_support/all'
require 'pry'

require_relative 'author.rb'
require_relative 'book.rb'
require_relative 'published_book.rb'
require_relative 'reader.rb'
require_relative 'reader_with_book.rb'

class LibraryManager

  attr_accessor :readers, :books, :readers_with_books 
  attr_reader :statistics

  def initialize readers = [], books = [], readers_with_books = []
    @readers_with_books = readers_with_books
    @readers = readers
    @books = books
    @statistics = {}
    populate_statistics!
  end

  def new_book author, title, price, pages_quantity, published_at
    new_book = PublishedBook.new author, title, price, pages_quantity, published_at
    books.push new_book
    populate_statistics!
  end

  def new_reader  name, reading_speed
    new_reader = Reader.new name, reading_speed
    readers.push new_reader
    populate_statistics!
  end

  def new_reader_with_book reader, published_book
    new_reader_with_book = ReaderWithBook.new(published_book, reader)
    readers_with_books.push new_reader_with_book
    populate_statistics!
  end

  def get_book_by_title title
    books.find { |book| book.title == title}
  end

  def get_reader_by_name name
    readers.find { |reader| reader.name == name }
  end

  def get_reader_with_book_by_name name
    readers_with_books.find { |reader_with_book| reader_with_book.reader_name == name }
  end

  def give_book_to_reader reader_name, book_title
    reader = get_reader_by_name reader_name
    book = get_book_by_title book_title
    reader_with_book = ReaderWithBook.new(books.delete(book), readers.delete(reader))
    readers_with_books.push reader_with_book
    populate_statistics!
  end

  def read_the_book reader_name, duration
    ReaderWithBook.find_reader_and_update_current_page @readers_with_books, reader_name, duration
    populate_statistics!
  end

  def most_popular_author
    most_popular_author_name = @statistics["authors"].first[0]
    @statistics["authors"].each do |author|
      most_popular_author_name = author[0] if @statistics["authors"][most_popular_author_name]["pages"] < @statistics["authors"][author[0]]["pages"]
    end
    most_popular_author = @statistics["authors"][most_popular_author_name]
    most_popular_author["author_name"] = most_popular_author_name
    most_popular_author
  end

  def most_popular_book
    most_popular_book_title = @statistics["book_titles"].first[0] 
    @statistics["book_titles"].each do |book|
      most_popular_book_title = book[0] if @statistics["book_titles"][most_popular_book_title]["reading_hours"] < @statistics["book_titles"][book[0]]["reading_hours"]
    end
    most_popular_book = @statistics["book_titles"][most_popular_book_title]
    most_popular_book["book_title"] = most_popular_book_title
    most_popular_book
  end

  def most_productive_reader
    most_productive_reader_name = @statistics["readers"].first[0] 
    @statistics["readers"].each do |reader|
      most_productive_reader_name = reader[0] if @statistics["readers"][most_productive_reader_name]["pages"] < @statistics["readers"][reader[0]]["pages"]
    end
    most_productive_reader = @statistics["readers"][most_productive_reader_name]
    most_productive_reader["reader_name"] = most_productive_reader_name
    most_productive_reader
  end

  def reader_notification reader_name
    params = reader_notification_params reader_name
    <<-TEXT
Dear #{reader_name}!

You should return a book "#{params[:book_title]}" authored by #{params[:author_name]} in #{params[:time_untill_deadline]} hours.

Otherwise you will be charged $#{params[:penalty_per_hour]} per hour.

By the way, you are on #{params[:current_page]} page now and you need #{params[:time_to_finish]} hours to finish reading "#{params[:book_title]}"
TEXT

  end

  def librarian_notification
    <<-TEXT
Hello,

There are #{librarian_notification_params[:quantity_of_books]} published books in the library.

There are #{librarian_notification_params[:quantity_of_readers]} readers and #{librarian_notification_params[:quantity_of_readers_with_books]} of them are reading the books.

#{librarian_notification_params[:readers_info]}
TEXT
  end

  def statistics_notification
    <<-TEXT
Hello,

The library has: #{statistics_notification_params[:quantity_of_books]} books, #{statistics_notification_params[:quantity_of_authors]} authors, #{statistics_notification_params[:quantity_of_readers]} readers

The most popular author is #{most_popular_author["author_name"]}: #{most_popular_author["pages"]} pages has been read by #{most_popular_author["readers"].count} readers in #{most_popular_author["books"]} books.

The most productive reader is #{most_productive_reader["reader_name"]}: he had read #{most_productive_reader["pages"]} pages in #{most_productive_reader["books"]} books authored by #{most_productive_reader["authors"].count} authors.

The most popular book is "#{most_popular_book["book_title"]}" authored by #{most_popular_book["author"]}: it had been read for #{most_popular_book["reading_hours"]} hours by #{most_popular_book["readers"].count} readers.
TEXT

  end

  private

  def reader_notification_params reader_name
    reader_with_book = get_reader_with_book_by_name reader_name
    {
      book_title: reader_with_book.book_title,
      author_name: reader_with_book.author_name,
      time_untill_deadline: ((reader_with_book.return_date.to_time.to_i - Time.now.to_i) / 3600.0).round(2),
      penalty_per_hour: reader_with_book.amazing_book.penalty_per_hour.round / 100.0,
      current_page: reader_with_book.current_page,
      time_to_finish: reader_with_book.time_to_finish.round(2)
    }
  end

  def librarian_notification_params
    readers_info = ""
    readers_with_books.each do |r|
      readers_info += (r.reader_name + " is reading \"" + r.book_title + "\" - should return on " + r.return_date.strftime("%F") + " at " + r.return_date.strftime("%r") + " - " + (r.time_to_finish.round(2)).to_s + " hours of reading is needed to finish.\n\n")
    end
    {
      quantity_of_books: books.count + readers_with_books.count,
      quantity_of_readers: readers.count + readers_with_books.count,
      quantity_of_readers_with_books: readers_with_books.count,
      readers_info: readers_info
    }
  end

  def statistics_notification_params
    
    {
      quantity_of_books: books.count + readers_with_books.count,
      quantity_of_authors: @statistics["authors"].count, 
      quantity_of_readers: readers.count + readers_with_books.count,
      
    }

  end

  def populate_statistics!
    @statistics = statistics_sample
    readers_with_books.each do |r|
      @statistics["authors"][r.author_name] ||= {"pages" => 0, "readers" => [], "books" => 0}
      @statistics["authors"][r.author_name]["pages"] += r.current_page
      @statistics["authors"][r.author_name]["readers"] |= [r.reader_name]
      @statistics["authors"][r.author_name]["books"] += 1
      @statistics["readers"][r.reader_name] ||= {"pages" => 0, "authors" => [], "books" => 0}
      @statistics["readers"][r.reader_name]["pages"] += r.current_page
      @statistics["readers"][r.reader_name]["authors"] |= [r.author_name]
      @statistics["readers"][r.reader_name]["books"] += 1
      @statistics["book_titles"][r.book_title] ||= {"author" => "", "reading_hours" => 0, "readers" => []}
      @statistics["book_titles"][r.book_title]["author"] += r.author_name
      @statistics["book_titles"][r.book_title]["reading_hours"] += r.reading_hours
      @statistics["book_titles"][r.book_title]["readers"] |= [r.reader_name]
    end
    puts librarian_notification
  end

  def statistics_sample
    {
      "authors" => {},
      "readers" => {},
      "book_titles" => {}      
    }
  end

end
