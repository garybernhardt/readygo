require_relative "readysetgo"

ready "Allocation" do
  go("#close") do
    sleep(0.01)
  end
end
