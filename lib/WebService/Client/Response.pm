package WebService::Client::Response;
use Moo;

# VERSION

use JSON::MaybeXS ();
use Scalar::Util qw(blessed);

has res => (
    is => 'ro',
    isa => sub {
        die 'res must be a HTTP::Response object'
            unless blessed($_[0]) && $_[0]->isa('HTTP::Response');
    },
    required => 1,
    handles => [qw(
        code
        content
        decoded_content
        is_error
        is_success
        status_line
    )],
);

has json => (
    is      => 'ro',
    lazy    => 1,
    default => sub { JSON::MaybeXS->new() },
);

sub data {
    my ($self) = @_;
    return $self->json->decode($self->decoded_content);
}

sub ok {
    my ($self) = @_;
    return $self->is_success;
}

1;
