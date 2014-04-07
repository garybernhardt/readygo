require_relative "readysetgo"

ready "something" do
  go("something") do
    rand * 0.5
  end
end
