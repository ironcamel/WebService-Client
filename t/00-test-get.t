#!/usr/bin/env perl

use strict;
use warnings;

use Test::LWP::UserAgent;
use Test::More;

{
  package WebService::Foo;
  use Moo;
  with 'WebService::Client';

  has '+base_url' => ( default => 'https://example.com' );

  sub get_widgets {
    my $self = shift;
    return $self->get("/widgets");
  }

  sub get_widget {
    my ($self, $id) = @_;
    return $self->get("/widgets/$id");
  }

  sub search_widgets {
    my ($self, $params) = @_;
    return $self->get("/widgets", $params);
  }

  sub create_widget {
    my ($self, $widget_data) = @_;
    return $self->post("/widgets", $widget_data);
  }
}

subtest 'GET with query params (default: php style)' => sub {
  my $useragent = Test::LWP::UserAgent->new;
  $useragent->map_response(
    qr{example.com},
    HTTP::Response->new('200', 'OK', ['Content-Type' => 'application/json'], '{}'),
  );

  my $webservice = WebService::Foo->new(ua => $useragent);
  is $webservice->array_query_style, 'php', 'default array_query_style is php';

  $webservice->get('/foo', { colour => 'blue' });
  my $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo?colour=blue', 'simple scalar param';

  $webservice->get('/foo', { q => 'hello world' });
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo?q=hello+world', 'spaces encoded as +';

  $webservice->get('/foo', { name => 'foo&bar=baz' });
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo?name=foo%26bar%3Dbaz', 'special chars encoded';

  $webservice->get('/foo', { ids => [1, 2, 3] });
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo?ids%5B%5D=1&ids%5B%5D=2&ids%5B%5D=3', 'array param uses php-style brackets';

  $webservice->get('/foo', {});
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo', 'empty hashref adds no query string';

  $webservice->get('/foo');
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo', 'no params adds no query string';
};

subtest 'GET with query params (rfc style)' => sub {
  my $useragent = Test::LWP::UserAgent->new;
  $useragent->map_response(
    qr{example.com},
    HTTP::Response->new('200', 'OK', ['Content-Type' => 'application/json'], '{}'),
  );

  my $webservice = WebService::Foo->new(
    ua                => $useragent,
    array_query_style => 'rfc',
  );

  $webservice->get('/foo', { colour => 'blue' });
  my $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo?colour=blue', 'scalar param unchanged';

  $webservice->get('/foo', { ids => [1, 2, 3] });
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo?ids=1&ids=2&ids=3', 'array param uses repeated keys';

  $webservice->get('/foo', { q => 'hello world' });
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo?q=hello+world', 'special chars still encoded';

  $webservice->get('/foo', {});
  $url = $useragent->last_http_request_sent->uri;
  is "$url", 'https://example.com/foo', 'empty hashref still works';
};

subtest 'GET without params' => sub {
  my $useragent = Test::LWP::UserAgent->new;
  $useragent->map_response(
    qr{example.com/widgets},
    HTTP::Response->new(
      '200', 'OK', ['Content-Type' => 'application/json'], '[{"name": "widget1"}]'
    ),
  );

  my $webservice = WebService::Foo->new(ua => $useragent);

  my $widgets = $webservice->get_widgets();
  ok $widgets, 'can get success';
  ok @$widgets, 'deserialized get into a list';
  is scalar @$widgets, 1, 'correct amount of values in returned list';
};

subtest 'GET with gzipped response' => sub {
  use Compress::Zlib qw(memGzip);

  my $json_data = '{"name":"José"}';
  my $gzipped = memGzip($json_data);

  my $useragent = Test::LWP::UserAgent->new;
  $useragent->map_response(
    qr{example.com/gzip},
    HTTP::Response->new(
      '200', 'OK',
      ['Content-Type' => 'application/json', 'Content-Encoding' => 'gzip'],
      $gzipped,
    ),
  );

  my $webservice = WebService::Foo->new(ua => $useragent);

  my $result = $webservice->get('/gzip');
  ok $result, 'deserialized gzipped response';
  is $result->{name}, 'José', 'correct value from gzipped response';
};

done_testing();
