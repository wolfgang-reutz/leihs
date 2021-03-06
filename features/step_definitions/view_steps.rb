Then "$who sees '$what'" do | who, what |
  @response.should have_tag("a", what)
end

Then "he sees the '$title' list" do | title |
  response.should render_template("backend/#{title}/index")
end

Then /^(\w+) can "([^\"]*)"$/ do |who, what|
  @response.should have_tag("a", what)
end

When "lending_manager looks at the screen" do
  get backend_inventory_pool_path(@inventory_pool)
  @response = response
end

Then "it will fail with an error" do
  step "user sees an error message"
end

# Flash error message
Then "$who sees an error message" do |who|
  response.should have_tag('div.error')
end
