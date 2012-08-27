package Net::Amazon::Glacier;

use 5.10.0;
use strict;
use warnings;
use feature 'say';

use Net::Amazon::Signature;

use HTTP::Request;
use LWP::UserAgent;
use JSON::PP;
use POSIX qw/strftime/;
use Carp;

=head1 NAME

Net::Amazon::Glacier - An implementation of the Amazon Glacier RESTful API.

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';


=head1 SYNOPSIS

This module implements the Amazon Glacier RESTful API, version 2012-06-01 (current at writing). It can be used to manage Glacier vaults and upload archives to them. Amazon Glacier is Amazon's long-term storage service.

Perhaps a little code snippet.

	use Net::Amazon::Glacier;

	my $glacier = Net::Amazon::Glacier->new(
		'eu-west-1',
		'AKIMYACCOUNTID',
		'MYSECRET',
	);

	$glacier->create_vault( 'a_vault' );

The functions are intended to closely reflect Amazon's Glacier API. Please see Amazon's API reference for documentation of the functions: L<http://docs.amazonwebservices.com/amazonglacier/latest/dev/amazon-glacier-api.html>.

=head1 CONSTRUCTOR

=head2 new( $region, $account_id, $secret )

=cut

sub new {
	my $class = shift;
	my ( $region, $account_id, $secret ) = @_;
	my $self = {
		region => $region,
		ua     => LWP::UserAgent->new(),
		sig    => Net::Amazon::Signature->new( $account_id, $secret, $region, 'glacier' ),
	};
	bless $self, $class;
}

=head1 VAULT OPERATORS

=head2 create_vault( $vault_name )

Creates a vault with the specified name. Returns true on success, false on failure.

=cut

sub create_vault {
	my ( $self, $vault_name ) = @_;
	my $res = $self->_send_receive( PUT => "/-/vaults/$vault_name" );
	return $res->is_success;
}

=head2 delete_vault( $vault_name )

Deletes the specified vault. Returns true on success, false on failure.

=cut

sub delete_vault {
	my ( $self, $vault_name ) = @_;
	my $res = $self->_send_receive( DELETE => "/-/vaults/$vault_name" );
	return $res->is_success;
}

=head2 describe_vault( $vault_name )

Fetches information about the specified vault. Returns a hash reference with the keys described by L<http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-vault-get.html>. Returns false on failure.

=cut

sub describe_vault {
	my ( $self, $vault_name ) = @_;
	my $res = $self->_send_receive( GET => "/-/vaults/$vault_name" );
	return $self->_decode_and_handle_response( $res );
}

=head2 list_vaults( [$limit, [$marker] ]  )

Lists the vaults. Returns a hash reference with a "marker" key, for pagination, and a "VaultList", which describes the vaults. The content of the vault list, and how $limit and $marker can be used for pagination, is described by L<http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-vaults-get.html>. Returns false on failure.

=cut

sub list_vaults {
	my ( $self, $limit, $marker ) = @_;
	$limit //= 1000; # max and default
	my $uri = "/-/vaults?limit=$limit";
	$uri .= "&marker=$marker" if defined $marker;
	my $res = $self->_send_receive( GET => $uri );
	return $self->_decode_and_handle_response( $res );
}

=head1



# helper functions

sub _decode_and_handle_response {
	my ( $self, $res ) = @_;
	if ( $res->is_success ) {
		return decode_json( $res->decoded_content );
	} else {
		return undef;
	}
}

sub _send_receive {
	my $self = shift;
	my $req = $self->_craft_request( @_ );
	return $self->_send_request( $req );
}

sub _craft_request {
	my ( $self, $method, $url ) = @_;
	my $host = 'glacier.'.$self->{region}.'.amazonaws.com';
	my $req = HTTP::Request->new(
		$method => 'http://' . $host . $url,
		[
			'x-amz-glacier-version' => '2012-06-01',
			'Host' => $host,
			'Date' => strftime( '%Y%m%dT%H%M%SZ', gmtime ),
		]
	);
	my $signed_req = $self->{sig}->sign( $req );
	return $signed_req;
}

sub _send_request {
	my ( $self, $req ) = @_;
	my $res = $self->{ua}->request( $req );
	if ( $res->is_error ) {
		carp sprintf 'Non-successful response: %s (%s)', $res->status_line, $res->decoded_content;
	}
	return $res;
}

=head1 NOT IMPLEMENTED

The following parts of Amazon's API have not  been implemented in this module. This is mainly because the author hasn't had a use for them yet. If you do implement them, feel free to send me the patch.

=over 4

=item * PUT/GET/DELETE vault notifications

=item * Archive operations

=item * Multipart upload operations

=item * Job operations

=back

=head1 AUTHOR

Tim Nordenfur, C<< <tim at gurka.se> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-amazon-glacier at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Amazon-Glacier>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Amazon::Glacier


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Amazon-Glacier>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Amazon-Glacier>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Amazon-Glacier>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Amazon-Glacier/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Tim Nordenfur.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Net::Amazon::Glacier
