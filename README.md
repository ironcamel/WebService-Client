# NAME

WebService::Client - A base role for quickly and easily creating web service clients

# VERSION

version 0.0300

# SYNOPSIS

    {
        package WebService::Foo;
        use Moo;
        with 'WebService::Client';

        use Function::Parameters;

        has '+base_url' => ( default => 'https://foo.com/v1' );
        has auth_token  => ( is => 'ro', required => 1 );

        method BUILD() {
            $self->ua->default_header('X-Auth-Token' => $self->auth_token);
            # or if the web service uses http basic/digest authentication:
            # $self->ua->credentials( ... );
            # or
            # $self->ua->default_headers->authorization_basic( ... );
        }

        method get_widgets() {
            return $self->get("/widgets");
        }

        method get_widget($id) {
            return $self->get("/widgets/$id");
        }

        method create_widget($widget_data) {
            return $self->post("/widgets", $widget_data);
        }
    }

    my $client = WebService::Foo->new(
        auth_token => 'abc',
        logger     => Log::Tiny->new('/tmp/foo.log'), # optional
        timeout    => 10, # optional, defaults to 10
        retries    => 0,  # optional, defaults to 0
    );
    my $widget = $client->create_widget({ color => 'blue' });
    print $client->get_widget($widget->{id})->{color};

# DESCRIPTION

This module is a base role for quickly and easily creating web service clients.
Every time I created a web service client, I noticed that I kept rewriting the
same boilerplate code independent of the web service.
This module does the boring boilerplate for you so you can just focus on
the fun part - writing the web service specific code.

# METHODS

These are the methods this role composes into your class.
The HTTP methods (get, post, put, and delete) will return the deserialized
response data, assuming the response body contained any data.
This will usually be a hashref.
If the web service responds with a failure, then the corresponding HTTP
response object is thrown as an exception.
This exception is a [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object that has the
[HTTP::Response::Stringable](https://metacpan.org/pod/HTTP::Response::Stringable) role so it can be stringified.
GET requests that result in 404 or 410 will not result in an exception.
Instead, they will simply return `undef`.

The \`get/post/put/delete\` methods all can take an optional headers keyword
argument that is a hashref of custom headers.

## get

    $client->get('/foo');
    $client->get('/foo', { query => 'params' });
    $client->get('/foo', { query => [qw(array params)] });

Makes an HTTP POST request.

## post

    $client->post('/foo', { some => 'data' });
    $client->post('/foo', { some => 'data' }, headers => { foo => 'bar' });

Makes an HTTP POST request.

## put

    $client->put('/foo', { some => 'data' });

Makes an HTTP PUT request.

## delete

    $client->delete('/foo');

Makes an HTTP DELETE request.

## req

    my $req = HTTP::Request->new(...);
    $client->req($req);

This is called internally by the above HTTP methods.
You will usually not need to call this explicitly.
It is exposed as part of the public interface in case you may want to add
a method modifier to it.
Here is a contrived example:

    around req => sub {
        my ($orig, $self, $req) = @_;
        $req->authorization_basic($self->login, $self->password);
        return $self->$orig($req, @rest);
    };

## log

Logs a message using the provided logger.

# ATTRIBUTES

## base\_url

This is the only attribute that is required.
This is the base url that all request will be made against.

## ua

Optional. A proper default LWP::UserAgent will be created for you.

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

# EXAMPLES

Here are some examples of web service clients built with this role.
You can view their source to help you get started.

- [Business::BalancedPayments](https://metacpan.org/pod/Business::BalancedPayments)
- [WebService::HipChat](https://metacpan.org/pod/WebService::HipChat)
- [WebService::Lob](https://metacpan.org/pod/WebService::Lob)
- [WebService::SmartyStreets](https://metacpan.org/pod/WebService::SmartyStreets)
- [WebService::Stripe](https://metacpan.org/pod/WebService::Stripe)

# SEE ALSO

- [Net::HTTP::API](https://metacpan.org/pod/Net::HTTP::API)
- [Role::REST::Client](https://metacpan.org/pod/Role::REST::Client)

# AUTHOR

Naveed Massjouni <naveed@vt.edu>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Naveed Massjouni.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
