# products service: serves the product catalog.
require "sinatra"
require "json"

set :bind, "0.0.0.0"
set :port, ENV.fetch("PORT", 4567).to_i
set :server, :puma

PRODUCTS = JSON.parse(File.read(File.join(__dir__, "products.json"))).freeze

before { content_type :json }

get "/healthz" do
  { status: "ok", service: "products" }.to_json
end

get "/api/products" do
  items = PRODUCTS
  items = items.select { |p| p["category"].casecmp?(params[:category]) } if params[:category]
  { count: items.size, items: items }.to_json
end

get "/api/products/:id" do
  product = PRODUCTS.find { |p| p["id"] == params[:id].to_i }
  halt 404, { error: "product not found" }.to_json unless product
  product.to_json
end
