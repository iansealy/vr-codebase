package Sfind::Well_Library; 
=head1 NAME

Sfind::Well_Library - Sequence Tracking for a library in a well not a library_tube

=head1 SYNOPSIS
    my $lib = Sfind::Well_Library->new({dbh => $dbh, id => $library_id});

    #get arrayref of sequencing requests on a library
    my $reqs = $library->seq_requests();

    my $id = $library->id();
    my $name = $library->name();


=head1 DESCRIPTION

An object describing the tracked properties of a library.

=head1 CONTACT

jws@sanger.ac.uk

=head1 METHODS

=head2 new

  Arg [1]    : hashref: dbh => database handle to seqtracking database
                        id  => librarytube asset id 
  Example    : my $lib = Sfind::Well_Library->new({dbh=>$dbh, id=>$id};)
  Description: Returns Well_Library object by library_id
  Returntype : Sfind::Well_Library object


=head2 seq_requests

  Arg [1]    : None
  Example    : my $seq_requests = $library->seq_requests();
  Description: Returns a ref to an array of the seq_request objects that are associated with this library.
  Returntype : ref to array of Sfind::Seq_Request objects


=head2 seq_request_ids

  Arg [1]    : None
  Example    : my $seq_request_ids = $library->seq_request_ids();
  Description: Returns a ref to an array of the seq_request IDs that are associated with this library, including those on multiplexes that this library is in
  Returntype : ref to array of integer seq request IDs


=head2 id

  Arg [1]    : None
  Example    : my $id = $lib->id();
  Description: Retrieve ID of a library
  Returntype : Integer asset_id


=head2 sample_id

  Arg [1]    : None
  Example    : my $sample_id = $lib->sample_id();
  Description: Retrieve sample ID of a library
  Returntype : Integer sample id
  

=head2 name

  Arg [1]    : None
  Example    : my $name = $lib->name();
  Description: Retrieve library name.  NB Well_Libraries aren't library_tubes
                and the name provided might not be in sequencescape  
  Returntype : string


=head2 prep_status

  Arg [1]    : None
  Example    : my $prep_status = $lib->prep_status();
  Description: Retrieve library state
  Returntype : string


=head2 get_seq_request_by_id

  Arg [1]    : None
  Example    : my $seqrequest = $lib->get_seq_request_by_id(7447);
  Description: retrieve seq_request object by sequencescape id
  Returntype : Sfind::Seq_Request object


=head2 get_lane_by_id

  Arg [1]    : None
  Example    : my $lane = $lib->get_lane_by_id(7447);
  Description: retrieve NPG lane object by id
  Returntype : Sfind::Lane object


=head2 fragment_size

  Arg [1]    : None
  Example    : my ($frag_from, $frag_to) = @{$lib->fragment_size};
  Description: Fetches requested library fragment size, as a pair of from and to sizes
  Returntype : arrayref of [from, to] sizes or undefs


=head2 fragment_size_from

  Arg [1]    : none
  Example    : my $frag_from = $request->fragment_size_from();
  Description: Retrieve fragment size from on request
  Returntype : integer


=head2 fragment_size_to

  Arg [1]    : none
  Example    : my $frag_to = $request->fragment_size_to();
  Description: Retrieve fragment size to on request
  Returntype : integer


=head2 type

  Arg [1]    : None
  Example    : my $lib_type = $lib->type();
  Description: returns type of library, if in database.  e.g. 'Standard', 'No PCR'
  Returntype : string or undef


=head2 multiplex_pool_asset_ids

  Arg [1]    : None
  Description: Retrieve multiplex_tube_asset_ids
  Returntype : reference to a array


=head2 is_tagged

  Arg [1]    : None
  Example    : my $tag = $lib->is_tagged();
  Description: Retrieve whether Well_Library is tagged.  The tag is a short sequence tag added to each Well_Library molecule so that it can be sequenced in a multiplex and the resulting mix resolved by the tag sequence.
  Returntype : boolean


=head2 tag_id

  Arg [1]    : None
  Example    : my $tag_id = $lib->tag_id();
  Description: Retrieve tag ID of a library
  Returntype : int


=head2 tag_group_id

  Arg [1]    : None
  Example    : my $tag_group_id = $lib->tag_group_id();
  Description: Retrieve tag group ID.  Can have the same tag id in multiple tag groups.
  Returntype : int


=head2 tag_sequence

  Arg [1]    : None
  Example    : my $tag_sequence = $lib->tag_sequence();
  Description: Retrieve tag sequence.
  Returntype : string

=cut

use Moose;
use namespace::autoclean;
use Sfind::Library;
extends 'Sfind::Library';

# Populate the parameters from the database
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    
    my $argref = $class->$orig(@_);

    die "Need to call with a well internal id" unless $argref->{id};
    my $sql = qq[select * from current_wells where internal_id = ?];
    my $id_ref = $argref->{dbh}->selectrow_hashref($sql, undef, ($argref->{id}));
    if ($id_ref){
        foreach my $field(keys %$id_ref){
            $argref->{$field} = $id_ref->{$field};
        }
    };
    # hacks to make a well look like a library
    $argref->{name} = $argref->{sample_name}.' '.$argref->{id} unless $argref->{name};

    $argref->{library_type} = "well";   # all we have, really


    # get pulldown_multiplexed_library_tube, tag is off that.
    $sql = qq[select distinct tag_internal_id,receptacle_internal_id as pulldown_tube_id
                from aliquots
                where library_internal_id=?
                and receptacle_type in ("pulldown_multiplexed_library_tube","multiplexed_library_tube")
                and is_current=1];
    
    $id_ref = $argref->{dbh}->selectrow_hashref($sql, undef, ($argref->{id}));
   # use Data::Dumper; print Dumper($id_ref);

    if ($id_ref && $id_ref->{pulldown_tube_id}){
        # OK, have a pulldown tube, get tag info
        my $tag_internal_id = $id_ref->{tag_internal_id};

        # get tag info
        $sql = qq[select map_id as tag_map_id, internal_id as tag_internal_id,
                        tag_group_internal_id, expected_sequence
                    from current_tags 
                    where internal_id=?
                    ];
        
        $id_ref = $argref->{dbh}->selectrow_hashref($sql, undef, ($tag_internal_id));
        if ($id_ref){
            foreach my $field(keys %$id_ref){
                $argref->{$field} = $id_ref->{$field};
            }
        }
    }

    return $argref;
};


###############################################################################
# BUILDERS
###############################################################################

sub _get_mplex_pool_ids{
    my ($self) = @_;
    my @mplex_ids;
    
    my $sql = qq[select distinct receptacle_internal_id as mplex_id 
                from aliquots
                where library_uuid=?
                and receptacle_type in("pulldown_multiplexed_library_tube", "multiplexed_library_tube")
                and is_current=1];
    
    my $sth = $self->_dbh->prepare($sql);
    $sth->execute($self->uuid);
    foreach(@{$sth->fetchall_arrayref()}){
        push @mplex_ids, $_->[0];
    }

    @mplex_ids = sort {$a <=> $b} @mplex_ids;



    return \@mplex_ids;
}

1;
