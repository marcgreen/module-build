package Module::Build::Notes;

# A class for persistent hashes

use strict;
use Data::Dumper;
use IO::File;

sub new {
  my $class = shift;
  return bless {
		disk => {},
		new  => {},
		@_,
	       }, $class;
}

sub restore {
  my ($class, $file) = @_;
  my $self = $class->new( file => $file );

  my $fh = IO::File->new("< $file") or die "Can't read $file: $!";
  $self->{disk} = eval do {local $/; <$fh>};
  die $@ if $@;
  return $self;
}

sub access {
  my $self = shift;
  return $self->read() unless @_;
  
  my $key = shift;
  return $self->read($key) unless @_;
  
  my $value = shift;
  return $self->write({ $key => $value });
}

sub has_data {
  my $self = shift;
  return keys %{$self->read()} > 0;
}

sub read {
  my $self = shift;

  if (@_) {
    # Return 1 key as a scalar
    my $key = shift;
    return $self->{new}{$key} if exists $self->{new}{$key};
    return $self->{disk}{$key};
  }
   
  # Return all data
  my $out = (keys %{$self->{new}}
	     ? {%{$self->{disk}}, %{$self->{new}}}
	     : $self->{disk});
  return wantarray ? %$out : $out;
}

sub write {
  my ($self, $href) = @_;
  $href ||= {};
  
  @{$self->{new}}{ keys %$href } = values %$href;  # Merge

  # Do some optimization to avoid unnecessary writes
  foreach my $key (keys %{ $self->{new} }) {
    next if ref $self->{new}{$key};
    next if ref $self->{disk}{$key} or !exists $self->{disk}{$key};
    delete $self->{new}{$key} if $self->{new}{$key} eq $self->{disk}{$key};
  }
  
  if (my $file = $self->{file}) {
    return if -e $file and !keys %{ $self->{new} };  # Nothing to do
    
    @{$self->{disk}}{ keys %{$self->{new}} } = values %{$self->{new}};  # Merge 
    $self->_dump($file, $self->{disk});
   
    $self->{new} = {};
  }
  return $self->read;
}

sub _dump {
  my ($self, $file, $data) = @_;
  
  my $fh = IO::File->new("> $file") or die "Can't create '$file': $!";
  local $Data::Dumper::Terse = 1;
  print $fh Data::Dumper::Dumper($data);
}

1;
