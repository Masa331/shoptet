# Shoptet

This is Ruby API wrapper for [Shoptet API](https://shoptet.docs.apiary.io) which provides access to e-shop data for addon developers.

# How to install

Currently only through Github:
```
gem 'shoptet', github: 'Masa331/shoptet'
```

# How to use

## Setup

First instantiate Shoptet which then represents connection to one specific shop
```
api = Shoptet.new(oauth_url, oauth_token, api_token, on_token_error)
```
And now you can access the data
```
api.price_lists
# => returns Enumerator with all price lists

```
### params for `::new`

#### * oauth_url
string with the oauth url for the partner shop under which is the addon registered.

#### oauth_token
string or nil with oauth token(the one you get during addon instalation process) used for creating api tokens. This gem can function without it but isn't able to auto re-create api tokens when necessary then.

#### api_token
string or nil with api token for accessing actual data. If it's not provided or is expired then this gem will request new one with the provided oauth token.

#### on_token_error
proc with what happens when missing or expired api token is encountered. If it's not provided then the default behaviour is to request new api token and store and use the new token only in api instance. The default proc looks like this
```
DEFAULT_ON_TOKEN_ERROR = -> (api) do
  api.api_token = api.new_api_token
end
```

Custom proc can be used to add some special logic for this event like for example storing the new token also somewhere in the databse. The proc will be called with the api instance.

For the common scenario when working with Rails and ActiveRecord this gem also provides proc which stores the new token in ActiveRecord model. The proc can be instantiated like this `Shoptet.ar_on_token_error(my_model_instance)` and expects the model to have `#api_token` setter defined. The exact behaviour can be seen in the [code]().

## Parallel requests

This gem fires only one network request at a time(of course) so some paralelization or whatnot is up to you.

## Exceptions

This gem fires special exceptions on various events.

`Shoptet::Error` when some general error occurs  
`Shoptet::AddonSuspended` when you are trying to access api for shop which has your addon suspended  
`Shoptet::NoRights` when you try to access api endpoint which is not approved  
`Shoptet::SlowDown` when 429 is returned from the api  
`Shoptet::InvalidOauthToken` when invalid oauth token is used

## Collection endpoints

Methods for accessing collections(products, orders, ...) automatically handle pagination so you don't have to do it manually. These collection methods return instances of `Enumerator` on which you can run standard methods like `#each`, `#map`, etc.

Also they accept hash with params which will be passed to Shoptet api. Through this you can set various filters and pagination.

* `Shoptet#products(api_params: {})`
* `Shoptet#products_changes(api_params: {})`
* `Shoptet#supplies(api_params: {})`
* `Shoptet#product_categories(api_params: {})`
* `Shoptet#price_lists(api_params: {})`

## Detail endpoints

* `Shoptet#product(guid)`
* `Shoptet#order(code)`

## Other

* `Shoptet#new_api_token` - this returns new api token created with oauth token
* `Shoptet::install` - TODO

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
