package TPath::Selector::Test::Self;

# ABSTRACT: note to self: analog of dfh.treepath.SelfSelector

use Moose;
use namespace::autoclean;

=head1 ROLES

L<TPath::Selector::Test>

=cut

with 'TPath::Selector::Test';

=method candidates

Expects node, collection, and index. Returns node.

=cut

sub candidates {
    my ( $self, $n, $c, $i ) = @_;
    return $n;
}

__PACKAGE__->meta->make_immutable;

1;
