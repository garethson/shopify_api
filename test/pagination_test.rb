require 'test_helper'

class PaginationTest < Test::Unit::TestCase
  def setup
    super

    @version = ShopifyAPI::ApiVersion::Release.new('2019-07')
    ShopifyAPI::Base.api_version = @version.to_s
    @next_page_info = "eyJkaXJlY3Rpb24iOiJuZXh0IiwibGFzdF9pZCI6NDQwMDg5NDIzLCJsYXN0X3ZhbHVlIjoiNDQwMDg5NDIzIn0%3D"
    @previous_page_info = "eyJsYXN0X2lkIjoxMDg4MjgzMDksImxhc3RfdmFsdWUiOiIxMDg4MjgzMDkiLCJkaXJlY3Rpb24iOiJuZXh0In0%3D"

    @next_link_header = "<https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?page_info=#{@next_page_info}>; rel=\"next\""
    @previous_link_header = "<https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?page_info=#{@previous_page_info}>; rel=\"previous\""
  end

  test "navigates using next and previous link headers" do
    link_header =
      "<https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?page_info=#{@previous_page_info}>; rel=\"previous\",\
      <https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?page_info=#{@next_page_info}>; rel=\"next\""

    fake 'orders', :method => :get, :status => 200, api_version: @version, :body => load_fixture('orders'), :link => link_header
    orders = ShopifyAPI::Order.all

    fake(
      'orders',
      url: "https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?page_info=#{@next_page_info}",
      method: :get,
      status: 200,
      body: load_fixture('orders')
    )

    next_page = orders.fetch_next_page
    assert_equal 450789469, next_page.first.id

    fake(
      'orders',
      url: "https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?page_info=#{@previous_page_info}",
      method: :get,
      status: 200,
      body: load_fixture('orders')
    )

    previous_page = orders.fetch_previous_page
    assert_equal 450789469, next_page.first.id
  end

  test "retains previous querystring parameters" do
    fake(
      'orders',
      method: :get,
      status: 200,
      api_version: @version,
      url: "https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?fields=id%2Cupdated_at",
      body: load_fixture('orders'),
      link: @next_link_header
    )
    orders = ShopifyAPI::Order.where(fields: 'id,updated_at')

    fake(
      'orders',
      method: :get,
      status: 200,
      api_version: @version,
      url: "https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?fields=id%2Cupdated_at&page_info=eyJkaXJlY3Rpb24iOiJuZXh0IiwibGFzdF9pZCI6NDQwMDg5NDIzLCJsYXN0X3ZhbHVlIjoiNDQwMDg5NDIzIn0%3D",
      body: load_fixture('orders')
    )
    next_page = orders.fetch_next_page
    assert_equal 450789469, next_page.first.id
  end

  test "returns empty next page if just the previous page is present" do
    fake 'orders', :method => :get, :status => 200, api_version: @version, :body => load_fixture('orders'), :link => @previous_link_header
    orders = ShopifyAPI::Order.all

    next_page = orders.fetch_next_page
    assert_empty next_page
  end

  test "returns an empty previous page if just the next page is present" do
    fake 'orders', :method => :get, :status => 200, api_version: @version, :body => load_fixture('orders'), :link => @next_link_header
    orders = ShopifyAPI::Order.all

    next_page = orders.fetch_previous_page
    assert_empty next_page
  end

  test "#next_page? returns true if next page is present" do
    fake 'orders', :method => :get, :status => 200, api_version: @version, :body => load_fixture('orders'), :link => @next_link_header
    orders = ShopifyAPI::Order.all

    assert orders.next_page?
  end

  test "#next_page? returns false if next page is not present" do
    fake 'orders', :method => :get, :status => 200, api_version: @version, :body => load_fixture('orders'), :link => @previous_link_header
    orders = ShopifyAPI::Order.all

    refute orders.next_page?
  end

  test "pagination handles no link headers" do
    fake 'orders', :method => :get, :status => 200, api_version: @version, :body => load_fixture('orders')
    orders = ShopifyAPI::Order.all

    refute orders.next_page?
    refute orders.previous_page?
    assert_empty orders.fetch_next_page
    assert_empty orders.fetch_previous_page
  end

  test "raises on invalid pagination links" do
    link_header = "<https://this-is-my-test-shop.myshopify.com/admin/api/2019-07/orders.json?page_info=#{@next_page_info}>;"
    fake 'orders', :method => :get, :status => 200, api_version: @version, :body => load_fixture('orders'), :link => link_header
    orders = ShopifyAPI::Order.all

    assert_raises ShopifyAPI::InvalidPaginationLinksError do
      orders.fetch_next_page
    end
  end

  test "raises on an invalid API version" do
    version = ShopifyAPI::ApiVersion::Release.new('2019-04')
    ShopifyAPI::Base.api_version = version.to_s

    fake 'orders', :method => :get, :status => 200, api_version: version, :body => load_fixture('orders')
    orders = ShopifyAPI::Order.all

    assert_raises NotImplementedError do
      orders.fetch_next_page
    end
  end
end
