Given "a $role for inventory pool '$ip_name' logs in as '$who'" do | role, ip_name, who |
  step "a #{role} '#{who}' for inventory pool '#{ip_name}'"
  step "he logs in"
  get backend_inventory_pool_path(@inventory_pool, :locale => 'en_US')
  @inventory_pool = assigns(:current_inventory_pool)
  @last_manager_login_name = who
end

When /^he logs in$/ do
  post "/session", :login => @user.login
end

# This one 'really' goes through the auth process
When /^I log in as '([^']*)' with password '([^']*)'$/ do |who,password|
  visit('/')
  fill_in 'login_user',     :with => who
  fill_in 'login_password', :with => password
  click_button 'Login'
end

Given /(his|her) password is '([^']*)'$/ do |foo,password|
  Factory.create_db_auth( :login => @user.login,
			  :password => password)
end

When 'I log in as the admin' do
  step 'I am on the home page'
  step 'I make sure I am logged out'
  step 'I fill in "login_user" with "super_user_1"'
  step 'I fill in "login_password" with "pass"'
  step 'I press "Login"'
end


# It's possible that previous steps leave the running browser instance in a logged-in
# state, which confuses tests that rely on "When I log in as the admin".
When 'I make sure I am logged out' do
  visit "/logout"
end
