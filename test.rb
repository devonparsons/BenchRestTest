require './LedgerTally'

#############
#
# Test Framework
#
#############

# In a full project or framework I would have set up a proper test framework like rspec
#  with associated tools like FactoryBot and WebMock
#  To keep it simple here I implemented a basic test framework

# With rspec and webmock I could keep LedgerTally as a black box, but this 
#   test class is simple enough for our purposes
class TestTally < LedgerTally
  attr_reader :download_count

  def initialize(responses)
    @responses = responses
    @download_count = 0
    super()
  end

  def download(url)
    @download_count += 1
    page_number = url.to_s[/\d+/]
    @responses[page_number]
  end

  def display
    # No-op
  end
end

Response = Struct.new(:code, :body)

def tallyFactory(transactions, transactions_per_page: 5)
  total = transactions.length
  pages = transactions.each_slice(transactions_per_page).map.with_index do |ts, i|
    page_number = i + 1
    data = { 
      "totalCount" => total,
      "page" => i + 1,
      "transactions": ts
    }
    [page_number.to_s, Response.new("200", data.to_json)]
  end.to_h

  TestTally.new(pages)
end

def assert(proposition)
  testname = caller[-3][/(?<=in `)\w+/]

  if proposition
    puts "#{testname}: Y"
  else
    puts "#{testname}: N"
  end
end

#############
#
# Test Suite
#
#############

def testAddsTransactionsOnSameDay
  tally = tallyFactory [
    { "Date": "2021-06-01", "Amount": "5.0" },  
    { "Date": "2021-06-01", "Amount": "10.0" },  
    { "Date": "2021-06-01", "Amount": "15.0" }
  ]

  tally.run!

  assert(tally.totals["2021-06-01"] == 30.0)
end

def testSeparatesTransactionsOnDifferentDays
  tally = tallyFactory [
    { "Date": "2021-06-01", "Amount": "10.0" },  
    { "Date": "2021-06-02", "Amount": "5.0" }
  ]

  tally.run!

  assert(tally.totals["2021-06-01"] == 10.0)
  assert(tally.totals["2021-06-02"] == 5.0)
end

def testAddsTransactionsAcrossPages
  tally = tallyFactory [
    { "Date": "2021-06-01", "Amount": "5.0" },  
    { "Date": "2021-06-01", "Amount": "10.0" }
  ], transactions_per_page: 1

  tally.run!

  assert(tally.totals["2021-06-01"] == 15.0)
end

def testDownloadsEveryPage
  tally = tallyFactory [
    { "Date": "2021-06-01", "Amount": "5.0" },  
    { "Date": "2021-06-02", "Amount": "10.0" },
    { "Date": "2021-06-03", "Amount": "15.0" },
    { "Date": "2021-06-04", "Amount": "20.0" },
    { "Date": "2021-06-05", "Amount": "25.0" },
    { "Date": "2021-06-06", "Amount": "30.0" },
    { "Date": "2021-06-07", "Amount": "35.0" }
  ], transactions_per_page: 2

  tally.run!

  assert(tally.download_count == 4)
end

def testAbortsWhenServiceUnavailable
  tally = TestTally.new({ "1" => Response.new("500", "A Problem Occurred")})

  begin
    tally.run!
    assert(false) # With a test framework I could expect an error thrown instead of this hack
  rescue StandardError => e
    assert(e.message =~ /Service Unavailable/)
  end
end

def testAbortsWhenJsonInvalid
  tally = TestTally.new({ "1" => Response.new("200", "This is not JSON")})

  begin
    tally.run!
    assert(false) # With a test framework I could expect an error thrown instead of this hack
  rescue StandardError => e
    assert(e.message =~ /invalid JSON/)
  end
end

def testAll
  testAddsTransactionsOnSameDay
  testSeparatesTransactionsOnDifferentDays
  testAddsTransactionsAcrossPages
  testDownloadsEveryPage
  testAbortsWhenServiceUnavailable
  testAbortsWhenJsonInvalid
end

testAll
