package TPath::Attributes::Standard;

# ABSTRACT: the standard collection of attributes available to any forester by default

=head1 DESCRIPTION

C<TPath::Attributes::Standard> provides the attributes available to all foresters.
C<TPath::Attributes::Standard> is a role which is composed into L<TPath::Forester>.

=cut

use v5.10;
no if $] >= 5.018, warnings => "experimental";

use Moose::Role;
use MooseX::MethodAttributes::Role;
use Scalar::Util qw(refaddr);

=head1 REQUIRED METHODS

=head2 _kids

See L<TPath::Forester>

=head2 children

See L<TPath::Forester>

=head2 parent

See L<TPath::Forester>

=cut

requires qw(_kids children parent);

=method C<@true>

Returns a value, 1, evaluating to true.

=cut

sub standard_true : Attr(true) {
    return 1;
}

=method C<@false>

Returns a value, C<undef>, evaluating to false.

=cut

sub standard_false : Attr(false) {
    return undef;
}

=method C<@this>

Returns the node itself.

=cut

sub standard_this : Attr(this) {
    my ( undef, $ctx ) = @_;
    return $ctx->n;
}

=method C<@uid>

Returns a string representing the unique path in the tree leading to this node.
This consists of the index of the node among its parent's children concatenated
to the uid of its parent with C</> as a separator. The uid of the root node is
always C</>. That of its second child is C</1>. That of the first child of this
child is C</1/0>. And so on.

=cut

sub standard_uid : Attr(uid) {
    my ( $self, $ctx ) = @_;
    my $original = $ctx;
    my @list;
    my ( $node, $i ) = ( $ctx->n, $ctx->i );
    while ( !$i->is_root($node) ) {
        my $ra = refaddr $node;
        $ctx = $ctx->wrap($node);
        my $parent = $self->parent( $original, $ctx );
        last unless $parent;
        my @children = $self->children( $parent->n, $i );
        for my $index ( 0 .. $#children ) {
            if ( refaddr $children[$index] == $ra ) {
                push @list, $index;
                last;
            }
        }
        $node = $parent->n;
    }
    return '/' . join( '/', @list );
}

=method C<@echo(//a)>

Returns its parameter.

=cut

sub standard_echo : Attr(echo) {
    my ( undef, undef, $o ) = @_;
    return $o;
}

=method C<@leaf>

Returns whether the node is without children.

=cut

sub standard_is_leaf : Attr(leaf) {
    my ( $self, $ctx ) = @_;
    return $self->is_leaf($ctx) ? 1 : undef;
}

=method C<@pick(//foo,1)>

Takes a collection and an index and returns the indexed member of the collection.

=cut

sub standard_pick : Attr(pick) {
    my ( $self, undef, $collection, $index ) = @_;
    if ( defined $index && $self->one_based ) {
        $index--;
    }
    return $collection->[ $index // 0 ];
}

=method C<@size(//foo)>

Takes a collection and returns its size.

=cut

sub standard_size : Attr(size) {
    my ( undef, undef, $collection ) = @_;
    return scalar @$collection;
}

=method C<@size>

Returns the size of the tree rooted at the context node.

=cut

sub standard_tsize : Attr(tsize) {
    my ( $self, $n, $i ) = @_;
    my $size = 1;
    ( $n, $i ) = ( $n->n, $n->i ) if blessed $n && $n->isa('TPath::Context');
    for my $kid ( $self->children( $n, $i ) ) {
        $size += $self->standard_tsize( $kid, $i );
    }
    return $size;
}

=method C<@width>

Returns the number of leave under the context node.

=cut

sub standard_width : Attr(width) {
    my ( $self, $ctx ) = @_;
    return 1 if $self->standard_is_leaf($ctx);
    my ( $n, $i ) = ( $ctx->n, $ctx->i );
    my $width = 0;
    for my $kid ( $self->children( $n, $i ) ) {
        $width += $self->standard_width( $ctx->wrap($kid) );
    }
    return $width;
}

=method C<@depth>

Returns the number of ancestors of the context node.

=cut

sub standard_depth : Attr(depth) {
    my ( $self, $ctx ) = @_;
    return 0 if $self->standard_is_root($ctx);
    my $depth    = -1;
    my $original = $ctx;
    do {
        $depth++;
        $ctx = $self->parent( $original, $ctx );
    } while ( defined $ctx );
    return $depth;
}

=method C<@height>

Returns the greatest number of generations, inclusive, separating this
node from a leaf. Leaf nodes have a height of 1, their parents, 2, etc.

=cut

sub standard_height : Attr(height) {
    my ( $self, $ctx ) = @_;
    return 1 if $self->standard_is_leaf($ctx);
    my ( $n, $i ) = ( $ctx->n, $ctx->i );
    my $max = 0;
    for my $kid ( $self->children( $n, $i ) ) {
        my $m = $self->standard_height( $ctx->wrap($kid) );
        $max = $m if $m > $max;
    }
    return $max + 1;
}

=method C<@root>

Returns whether the context node is the tree root.

=cut

sub standard_is_root : Attr(root) {
    my ( $self, $ctx ) = @_;
    return $ctx->i->is_root( $ctx->n ) ? 1 : undef;
}

=method C<@null>

Returns C<undef>. This is chiefly useful as an argument to other attributes. It will
always evaluate as false if used as a predicate.

=cut

sub standard_null : Attr(null) {
    return undef;
}

=method C<@index>

Returns the index of this node among its parent's children, or -1 if it is the root
node.

=cut

sub standard_index : Attr(index) {
    my ( $self, $ctx ) = @_;
    my ( $n, $i ) = ( $ctx->n, $ctx->i );
    return -1 if $i->is_root($n);
    my $original = $ctx;
    my $parent   = $self->parent( $original, $ctx );
    my $siblings = $self->_kids( $original, $parent );
    my $ra       = refaddr $n;
    my $idx;

    for my $index ( 0 .. $#$siblings ) {
        if ( refaddr $siblings->[$index]->n == $ra ) {
            $idx = $index;
            last;
        }
    }
    if ( defined $idx ) {
        $idx++ if $self->one_based;
        return $idx;
    }
    confess "$n not among children of its parent";
}

=method C<@log('m1','m2','m3','...')>

Prints each message argument to the log stream, one per line, and returns 1.
See attribute C<log_stream> in L<TPath::Forester>.

=cut

sub standard_log : Attr(log) {
    my ( $self, undef, @messages ) = @_;
    for my $m (@messages) {
        $self->log_stream->put($m);
    }
    return 1;
}

=method C<@id>

Returns the id of the current node, if any.

=cut

sub standard_id : Attr(id) {
    my ( $self, $ctx ) = @_;
    $self->id( $ctx->n );
}

=method C<@card(//a)>

Returns the cardinality of its parameter. If its parameter evaluates to a list reference, it is the
number of items in the list. If it evaluates to a hash reference, it is the number of mappings. The
usual parameters are expressions or attributes. Anything which evaluates to C<undef> will have a
cardinality of 0. Anything which does not evaluate to a collection reference will have a cardinality
of 1. 

  //foo[@card(bar) = @card(@quux)]

=cut

sub standard_card : Attr(card) {
    my ( undef, undef, $o ) = @_;
    return 0 unless defined $o;
    for ( ref $o ) {
        when ('HASH')  { return scalar keys %$o }
        when ('ARRAY') { return scalar @$o }
        default        { return 1 }
    }
}

=method C<@at(foo//bar, 'baz', 1, 2, 3)>

Returns the value of the named attribute with the given parameters at the first L<TPath::Context> selected by
the path parameter evaluated relative to the context node. In the case of

  @at(foo//bar, 'baz', 1, 2, 3)

The path parameter is C<foo//bar>, the relevant attribute is C<@baz>, and it will be evaluated using
the parameters 1, 2, and 3. Other examples:

  @at(leaf::*[1], 'id')   # the id of the second leaf under this node
  @at(*/*, 'height')      # the height of the first grandchild of this node
  @at(/>foo, 'depth')     # the depth of the closest foo node

It is the first L<TPath::Context> selected by the path whose attribute is evaluated, that is, 
the first node returned, so it is relevant that paths are evaluated left-to-right, depth-first, and 
post-ordered, descendants being returned before their ancestors.

=cut

sub standard_attr : Attr(at) {
    my ( $self, $ctx, $nodes, $attr, @params ) = @_;
    my @nodes = @$nodes;
    return undef unless @nodes;
    $self->attribute( $ctx->wrap( $nodes[0] ), $attr, @params );
}

=method C<@all(@a, b, 1, "foo")>

True if all its parameters evaluate to true, the standard boolean
interpretation being given to collection parameters.

=cut

sub standard_all : Attr(all) {
    my ( $self, undef, @params ) = @_;
    for (@params) {
        return undef unless $self->_booleanize($_);
    }
    return 1;
}

=method C<@none(@a, b, 1, "foo")>

True if all its parameters evaluate to false, the standard boolean
interpretation being given to collection parameters.

=cut

sub standard_none : Attr(none) {
    my ( $self, undef, @params ) = @_;
    for (@params) {
        return undef if $self->_booleanize($_);
    }
    return 1;
}

=method C<@some(@a, b, 1, "foo")>

True if any of its parameters evaluates to true, the standard boolean
interpretation being given to collection parameters.

=cut

sub standard_some : Attr(some) {
    my ( $self, undef, @params ) = @_;
    for (@params) {
        return 1 if $self->_booleanize($_);
    }
    return undef;
}

=method C<@one(@a, b, 1, "foo")>

True if only one of its parameters evaluates to true, the standard boolean
interpretation being given to collection parameters.

=cut

sub standard_one : Attr(one) {
    my ( $self, undef, @params ) = @_;
    my $found;
    for (@params) {
        if ( $self->_booleanize($_) ) {
            return undef if $found;
            $found = 1;
        }
    }
    return $found;
}

=method C<@tcount(@a, b, 1, "foo")>

Returns the number of parameters evaluating to true.

=cut

sub standard_tcount : Attr(tcount) {
    my ( $self, undef, @params ) = @_;
    my $found = 0;
    for (@params) {
        $found++ if $self->_booleanize($_);
    }
    return $found;
}

=method C<@fcount(@a, b, 1, "foo")>

Returns the number of parameters evaluating to false.

=cut

sub standard_fcount : Attr(fcount) {
    my ( $self, undef, @params ) = @_;
    my $found = 0;
    for (@params) {
        $found++ unless $self->_booleanize($_);
    }
    return $found;
}

=method C<@var(@a, "key")>
=method C<@v(@a, "key", "value")>

Returns the value of the given variable in the context, also setting it if the optional values
parameters are supplied. This attribute is accessible as either C<@var> or C<@v>

  my $e = $f->path('/*[@v("size", @tsize)]');
  $e->select($some_tree);
  say $e->vars->{size};   # prints the number of nodes in the tree

If a single parameter is passed in as the value, this value is stored under the key. If
more than one parameter is passed in, a reference to the values array is stored.

=cut

sub standard_var : Attr(var) {
    my ( undef, $ctx, $key, @values ) = @_;
    my $vars = $ctx->expression->vars;
    return $vars->{$key} unless @values;
    return $vars->{$key} = @values > 1 ? \@values : $values[0];
}

sub standard_v : Attr(v) {
    goto &standard_var;
}

=method C<@clear_var("key")>

Deletes the given value from the expression's variable hash, returning any
value deleted.

=cut

sub standard_clear_var : Attr(clear_var) {
    my ( undef, $ctx, $key) = @_;
    return delete $ctx->expression->vars->{$key};
}

# Converts a scalar to a boolean value, dereferencing hash and array refs.
sub _booleanize {
    my ( $self, $v ) = @_;
    for ( ref $v ) {
        when ('ARRAY') { $v = @$v }
        when ('HASH')  { $v = keys %$v }
    }
    return $v && 1;
}

1;
