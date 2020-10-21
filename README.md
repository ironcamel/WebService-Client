# NAME

WebService::Client - A base role for quickly and easily creating web service clients

# VERSION

version 1.0001

# SYNOPSIS

```perl
{
    package WebService::Foo;
    use Moo;
    with 'WebService::Client';

    has auth_token  => ( is => 'ro', required => 1 );

    sub BUILD {
        my ($self) = @_;
        $self->base_url('https://foo.com/v1');

        $self->ua->default_header('X-Auth-Token' => $self->auth_token);
        # or if the web service uses http basic/digest authentication:
        # $self->ua->credentials( ... );
        # or
        # $self->ua->default_headers->authorization_basic( ... );
    }

    sub get_widgets {
        my ($self) = @_;
        return $self->get("/widgets");
    }

    sub get_widget {
        my ($self, $id) = @_;
        return $self->get("/widgets/$id");
    }

    sub create_widget {
        my ($self, $widget_data) = @_;
        return $self->post("/widgets", $widget_data);
    }
}

my $client = WebService::Foo->new(
    auth_token => 'abc',
    logger     => Log::Tiny->new('/tmp/foo.log'), # optional
    log_method => 'info', # optional, defaults to 'DEBUG'
    timeout    => 10, # optional, defaults to 10
    retries    => 0,  # optional, defaults to 0
);
my $widget = $client->create_widget({ color => 'blue' });
print $client->get_widget($widget->{id})->{color};
```

Minimal example which retrieves the current Bitcoin price:

```perl
package CoinDeskClient;
use Moo;
with 'WebService::Client';

my $client = CoinDeskClient->new(base_url => 'https://api.coindesk.com/v1');
print $client->get('/bpi/currentprice.json')->{bpi}{USD}{rate_float};
```

Example using mode `v2`.
When using mode `v2`, the client's http methods will always return a
[WebService::Client::Response](https://metacpan.org/pod/WebService%3A%3AClient%3A%3AResponse) response object.

```perl
package CoinDeskClient;
use Moo;
with 'WebService::Client';

my $client = CoinDeskClient->new(
    mode => 'v2',
    base_url => 'https://api.coindesk.com/v1',
);
my $data = $client->get('/bpi/currentprice.json')->data;
print $data->{bpi}{USD}{rate_float};
```

# DESCRIPTION

This module is a base role for quickly and easily creating web service clients.
Every time I created a web service client, I noticed that I kept rewriting the
same boilerplate code independent of the web service.
This module does the boring boilerplate for you so you can just focus on
the fun part - writing the web service specific code.

# METHODS

These are the methods this role composes into your class.
The HTTP methods (get, post, put, and delete) will return the deserialized
response data, if the response body contained any data.
This will usually be a hashref.
If the web service responds with a failure, then the corresponding HTTP
response object is thrown as an exception.
This exception is a [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object that has the
[HTTP::Response::Stringable](https://metacpan.org/pod/HTTP%3A%3AResponse%3A%3AStringable) role so it can be easily logged.
GET requests that respond with a status code of `404` or `410` will not
throw an exception.
Instead, they will simply return `undef`.

The http methods `get/post/put/delete` can all take the following optional
named arguments:

- headers

    A hashref of custom headers to send for this request.
    In the future, this may also accept an arrayref.
    The header values can be any format that [HTTP::Headers](https://metacpan.org/pod/HTTP%3A%3AHeaders) recognizes,
    so you can pass `content_type` instead of `Content-Type`.

- serializer

    A coderef that does custom serialization for this request.
    Set this to `undef` if you don't want any serialization to happen for this
    request.

- deserializer

    A coderef that does custom deserialization for this request.
    Set this to `undef` if you want the raw http response body to be returned.

Example:

```perl
$client->post(
    /widgets,
    { color => 'blue' },
    headers      => { x_custom_header => 'blah' },
    serializer   => sub { ... },
    deserializer => sub { ... },
}
```

## get

```perl
$client->get('/foo');
$client->get('/foo', { query => 'params' });
$client->get('/foo', { query => [qw(array params)] });
```

Makes an HTTP GET request.

## post

```perl
$client->post('/foo', { some => 'data' });
$client->post('/foo', { some => 'data' }, headers => { foo => 'bar' });
```

Makes an HTTP POST request.

## put

```perl
$client->put('/foo', { some => 'data' });
```

Makes an HTTP PUT request.

## patch

```perl
$client->patch('/foo', { some => 'data' });
```

Makes an HTTP PATCH request.

## delete

```
$client->delete('/foo');
```

Makes an HTTP DELETE request.

## req

```perl
my $req = HTTP::Request->new(...);
$client->req($req);
```

This is called internally by the above HTTP methods.
You will usually not need to call this explicitly.
It is exposed as part of the public interface in case you may want to add
a method modifier to it.
Here is a contrived example:

```perl
around req => sub {
    my ($orig, $self, $req) = @_;
    $req->authorization_basic($self->login, $self->password);
    return $self->$orig($req, @rest);
};
```

## log

Logs a message using the provided logger.

# ATTRIBUTES

## base\_url

This is the only attribute that is required.
This is the base url that all request will be made against.

## ua

Optional. A proper default LWP::UserAgent will be created for you.

## json

Optional. A proper default JSON object will be created via [JSON::MaybeXS](https://metacpan.org/pod/JSON%3A%3AMaybeXS)

You can also pass in your own custom JSON object to have more control over
the JSON settings:

```perl
my $client = WebService::Foo->new(
    json => JSON::MaybeXS->new(utf8 => 1, pretty => 1)
);
```

## timeout

Optional.
Default is 10.

## retries

Optional.
Default is 0.

## logger

Optional.

## content\_type

Optional.
Default is `'application/json'`.

## serializer

Optional.
A coderef that serializes the request content.
Set this to `undef` if you don't want any serialization to happen.

## deserializer

Optional.
A coderef that deserializes the response body.
Set this to `undef` if you want the raw http response body to be returned.

# EXAMPLES

Here are some examples of web service clients built with this role.
You can view their source to help you get started.

- [Business::BalancedPayments](https://metacpan.org/pod/Business%3A%3ABalancedPayments)
- [WebService::HipChat](https://metacpan.org/pod/WebService%3A%3AHipChat)
- [WebService::Lob](https://metacpan.org/pod/WebService%3A%3ALob)
- [WebService::SmartyStreets](https://metacpan.org/pod/WebService%3A%3ASmartyStreets)
- [WebService::Stripe](https://metacpan.org/pod/WebService%3A%3AStripe)

# SEE ALSO

- [Net::HTTP::API](https://metacpan.org/pod/Net%3A%3AHTTP%3A%3AAPI)
- [Role::REST::Client](https://metacpan.org/pod/Role%3A%3AREST%3A%3AClient)

# CONTRIBUTORS

- Dean Hamstead <[https://github.com/djzort](https://github.com/djzort)>
- Todd Wade <[https://github.com/trwww](https://github.com/trwww)>

# AUTHOR

Naveed Massjouni <naveed@vt.edu>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Naveed Massjouni.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
