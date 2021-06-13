require 'net/http'
require 'json'

class LedgerTally
  ADDRESS = "https://resttest.bench.co/transactions"

  attr_reader :transactions, :totals

  def run!
    get_transactions
    compute_totals
    display
    # Arguably run! could catch errors but for this simple app it makes testing more convenient if it doesn't
  end

  def get_transactions
    first_page = get_page(1)
    records_per_page = first_page["transactions"].length # Possibly an invalid assumption, but unlikely
    pages = 
      if first_page["totalCount"] > records_per_page
        last_page = (first_page["totalCount"].to_f / records_per_page).ceil
        [first_page, *(2..last_page).map { |n| get_page(n) }]
      else
        # I prefer instantiating variables like 'pages' with their final value, as opposed to pushing repeatedly to an array (for example)
        [first_page] 
      end

    @transactions = pages.flat_map { |p| p["transactions"] }
    # Here we could filter our results for a specific date/ledger/company, since the API doesn't expose a filter for us
  end

  def get_page(page_number)
    url = URI.parse("#{ADDRESS}/#{page_number}.json")
    response = download(url)

    raise "Service Unavailable" unless response.code == "200"

    parse_page(response.body)
  end

  # This method will be a convenient test hook later
  def download(url)
    Net::HTTP.get_response(url)
  end

  def parse_page(page)
    JSON.parse(page)
    # No need for a custom data structure, but if the problem were more complicated we could instantiate one here
    # This would let us do some simple validation like asserting the expected keys are present
  rescue JSON::ParserError => e
    raise "Service responded with invalid JSON (#{e.message})"
  end

  def compute_totals
    # Default each new day's value to 0
    tally = Hash.new(0.0) 

    @transactions.each do |t|
      tally[t["Date"]] += t["Amount"].to_f
    end

    @totals = tally
  end

  def display
    @totals.keys.sort.each do |k|
      # Rounding hides float precision errors, we could have instead converted all amounts to cents before storing
      puts "#{k}: #{@totals[k].round(2)}" 
    end
  end
end
