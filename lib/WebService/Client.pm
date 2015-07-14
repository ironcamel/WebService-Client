package WebService::Client;
use Moo::Role;

# VERSION

use Carp qw(croak);
use HTTP::Request::Common qw(DELETE GET POST PUT);
use JSON qw(decode_json encode_json);
use LWP::UserAgent;

has base_url => ( is => 'ro', required => 1 );

has ua => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $ua = LWP::UserAgent->new;
        $ua->timeout($self->timeout);
        return $ua;
    },
);

has timeout => ( is => 'ro', default => 10 );

has retries => ( is => 'ro', default => 0 );

has logger => ( is => 'ro' );

has log_method => ( is => 'ro', default => 'DEBUG' );

has content_type => (
    is      => 'rw',
    default => 'application/json',
);

sub get {
    my ($self, $path, $params, %args) = @_;
    $params ||= {};
    my $headers = $self->_headers(%args);
    my $url = $self->_url($path);
    my $q = '';
    if (%$params) {
        my @items;
        while (my ($key, $value) = each %$params) {
            if ('ARRAY' eq ref $value) {
                push @items, map "$key\[]=$_", @$value;
            } else {
                push @items, "$key=$value";
            }
        }
        if (@items) {
            $q = '?' . join '&', @items;
        }
    }
    return $self->req(GET "$url$q", %$headers);
}

sub post {
    my ($self, $path, $params, %args) = @_;
    my $headers = $self->_headers(%args);
    my $url = $self->_url($path);
    return $self->req(POST $url, %$headers, _content($params, $headers));
}

sub put {
    my ($self, $path, $params, %args) = @_;
    my $headers = $self->_headers(%args);
    my $url = $self->_url($path);
    return $self->req(PUT $url, %$headers, _content($params, $headers));
}

sub delete {
    my ($self, $path, %args) = @_;
    my $headers = $self->_headers(%args);
    my $url = $self->_url($path);
    return $self->req(DELETE $url, %$headers);
}

sub req {
    my ($self, $req) = @_;
    $self->_log_request($req);

    my ($res, $num_attempts) = (undef, 0);
    do {
        sleep 1 if $num_attempts > 0;
        $res = $self->ua->request($req);
        $self->_log_response($res);
    }
    while ($self->_is_retryable($req, $res, ++$num_attempts));

    $self->prepare_response($res, $req, $num_attempts);
    return $self->parse_response($res, $req, $num_attempts);
}

sub log {
    my ($self, $msg) = @_;
    return unless $self->logger;
    my $log_method = $self->log_method;
    $self->logger->$log_method($msg);
}

sub prepare_response {
    my ($self, $res, $req, $num_attempts) = @_;
    Moo::Role->apply_roles_to_object($res, 'HTTP::Response::Stringable');
    return;
}

sub parse_response {
    my ($self, $res, $req, $num_attempts) = @_;

    return undef if $req->method eq 'GET' && $res->code =~ qr/ 404 | 410 /x;
    die $res if not $res->is_success;
    return decode_json($res->content) if $res->content;
    return 1;
}

sub _is_retryable {
    my ($self, $req, $res, $num_attempts) = @_;
    return ($res->is_server_error and $num_attempts <= $self->retries);
}

sub _url {
    my ($self, $path) = @_;
    croak 'The path is missing' unless defined $path;
    return $path =~ /^http/ ? $path : $self->base_url . $path;
}

sub _headers {
    my ($self, %args) = @_;
    my $headers = $args{headers} || {};
    croak 'The headers param must be a hashref' unless 'HASH' eq ref $headers;
    $headers->{content_type} = $self->content_type
        unless _content_type($headers);
    return $headers;
}

sub _log_request {
    my ($self, $req) = @_;
    $self->log(ref($self) . " REQUEST:\n" . $req->as_string);
}

sub _log_response {
    my ($self, $res) = @_;
    $self->log(ref($self) . " RESPONSE:\n" . $res->as_string);
}

sub _content_type {
    my ($headers) = @_;
    return $headers->{'Content-Type'}
        || $headers->{'content-type'}
        || $headers->{content_type};
}

sub _content {
    my ($params, $headers) = @_;
    my @content;
    if (defined $params) {
        $params = encode_json $params if _content_type($headers) =~ /json/;
        @content = ( content => $params );
    }
    return @content;
}

# ABSTRACT: A base role for quickly and easily creating web service clients

=head1 SYNOPSIS

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
        log_method => 'info', # optional, defaults to 'DEBUG'
        timeout    => 10, # optional, defaults to 10
        retries    => 0,  # optional, defaults to 0
    );
    my $widget = $client->create_widget({ color => 'blue' });
    print $client->get_widget($widget->{id})->{color};

=head1 DESCRIPTION

This module is a base role for quickly and easily creating web service clients.
Every time I created a web service client, I noticed that I kept rewriting the
same boilerplate code independent of the web service.
This module does the boring boilerplate for you so you can just focus on
the fun part - writing the web service specific code.

=head1 METHODS

These are the methods this role composes into your class.
The HTTP methods (get, post, put, and delete) will return the deserialized
response data, assuming the response body contained any data.
This will usually be a hashref.
If the web service responds with a failure, then the corresponding HTTP
response object is thrown as an exception.
This exception is a L<HTTP::Response> object that has the
L<HTTP::Response::Stringable> role so it can be stringified.
GET requests that result in 404 or 410 will not result in an exception.
Instead, they will simply return C<undef>.

The `get/post/put/delete` methods all can take an optional headers keyword
argument that is a hashref of custom headers.

=head2 get

    $client->get('/foo');
    $client->get('/foo', { query => 'params' });
    $client->get('/foo', { query => [qw(array params)] });

Makes an HTTP POST request.

=head2 post

    $client->post('/foo', { some => 'data' });
    $client->post('/foo', { some => 'data' }, headers => { foo => 'bar' });

Makes an HTTP POST request.

=head2 put

    $client->put('/foo', { some => 'data' });

Makes an HTTP PUT request.

=head2 delete

    $client->delete('/foo');

Makes an HTTP DELETE request.

=head2 req

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

=head2 log

Logs a message using the provided logger.

=head1 ATTRIBUTES

=head2 base_url

This is the only attribute that is required.
This is the base url that all request will be made against.

=head2 ua

Optional. A proper default LWP::UserAgent will be created for you.

=head2 timeout

Optional.
Default is 10.

=head2 retries

Optional.
Default is 0.

=head2 logger

Optional.

=head2 content_type

Optional.
Default is C<'application/json'>.

=head1 EXAMPLES

Here are some examples of web service clients built with this role.
You can view their source to help you get started.

=over

=item *

L<Business::BalancedPayments>

=item *

L<WebService::HipChat>

=item *

L<WebService::Lob>

=item *

L<WebService::SmartyStreets>

=item *

L<WebService::Stripe>

=back

=head1 SEE ALSO

=over

=item *

L<Net::HTTP::API>

=item *

L<Role::REST::Client>

=back

=cut

1;
