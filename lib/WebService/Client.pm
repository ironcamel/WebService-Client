package WebService::Client;
use Moo::Role;

# VERSION

use HTTP::Request::Common qw(DELETE GET POST PUT);
use JSON;
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

sub get {
    my ($self, $path, $params) = @_;
    $params ||= {};
    my $q = '';
    if (%$params) {
        $q = '?' . join '&', map { "$_=$params->{$_}" } keys %$params;
    }
    return $self->req(GET "$path$q");
}

sub post {
    my ($self, $path, $params) = @_;
    my $json = JSON->new();
    $json->convert_blessed(1);
    return $self->req(POST $path, content => $json->encode($params) );
}

sub put {
    my ($self, $path, $params) = @_;
    my $json = JSON->new();
    $json->convert_blessed(1);
    return $self->req(PUT $path, content => encode_json $params);
}

sub delete {
    my ($self, $path) = @_;
    return $self->req(DELETE $path);
}

# Prefix the path param of the http methods with the base_url
around qw(delete get post put) => sub {
    my $orig = shift;
    my $self = shift;
    my $path = shift;
    die 'Path is missing' unless $path;
    my $url = $self->_url($path);
    return $self->$orig($url, @_);
};

sub req {
    my ($self, $req) = @_;
    $req->header(content_type => 'application/json');
    $self->_log_request($req);
    my $res = $self->ua->request($req);
    Moo::Role->apply_roles_to_object($res, 'HTTP::Response::Stringable');
    $self->_log_response($res);

    my $retries = $self->retries;
    while ($res->code =~ /^5/ and $retries--) {
        sleep 1;
        $res = $self->ua->request($req);
        $self->_log_response($res);
    }

    return undef if $res->code =~ /404|410/;
    die $res unless $res->is_success;
    return $res->content ? decode_json($res->content) : 1;
}

sub _url {
    my ($self, $path) = @_;
    return $path =~ /^http/ ? $path : $self->base_url . $path;
}

sub _log_request {
    my ($self, $req) = @_;
    $self->log($req->method . ' => ' . $req->uri);
    my $content = $req->content;
    return unless length $content;
    $self->log($content);
}

sub _log_response {
    my ($self, $res) = @_;
    $self->log("$res");
}

sub log {
    my ($self, $msg) = @_;
    return unless $self->logger;
    $self->logger->DEBUG($msg);
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

=head1 DESCRIPTION

This module is a base role for quickly and easily creating web service clients.
Every time I created a web service client, I noticed that I kept rewriting the
same boilerplate code independent of the web service.
This module does the boring boilerplate for you so you can just focus on
the fun part - writing the web service specific code.

It is important to note that this only supports JSON based web services.
If your web service does not support JSON, then I am sorry.

=head1 METHODS

These are the methods this role composes into your class.
The HTTP methods (get, post, put, and delete) will return the deserialized
response data, assuming the response body contained any data.
This will usually be a hashref.
If the web service responds with a failure, then the corresponding HTTP
response object is thrown as an exception.
This exception is simply an L<HTTP::Response> object that can be stringified.
HTTP responses with a status code of 404 or 410 will not result in an exception.
Instead, the corresponding methods will simply return C<undef>.
The reasoning behind this is that GET'ing a resource that does not exist
does not warrant an exception.

=head2 get

    $client->get('/foo')

Makes an HTTP POST request.

=head2 post

    $client->post('/foo', { some => 'data' })

Makes an HTTP POST request.

=head2 put

    $client->put('/foo', { some => 'data' })

Makes an HTTP PUT request.

=head2 delete

    $client->delete('/foo')

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
