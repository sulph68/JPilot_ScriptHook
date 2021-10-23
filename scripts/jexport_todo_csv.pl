#!/usr/bin/perl
my $debug = 0;

use Palm::ToDo;
use Data::Dumper;

##
# define
##
my $jpilot = $ENV{HOME}."/.jpilot/raw/todoist.jpilot";
my $pdb_file = $ENV{HOME}."/.jpilot/ToDoDB.pdb";
my $pc3_file = $ENV{HOME}."/.jpilot/ToDoDB.pc3";

##
# Subroutines
##

sub map_id2category() {
	my ($id) = shift @_;
	return "Unfiled" if ($id == 0);
	return "Personal" if ($id == 1);
	return "Business" if ($id == 2);
	return "Unfiled"
}

sub map_category2id() {
	my ($category) = shift @_;
	return 0 if ($category eq "Unfiled");
	return 1 if ($category eq "Personal");
	return 2 if ($category eq "Business");
	return 0;
}

##
# Main code
##

# Read ToDo PDB
# print "JPilot Exporting ToDoDB.pdb file\n";
my $pdb = Palm::ToDo->new;
$pdb->Load($pdb_file);

# cycle through PC3 file
# print "JPilot Exporting ToDoDB.pc3 file\n";
my @pcrecords;
open(FILE, $pc3_file);
binmode FILE;
 
while (1) {
	my $buf = undef;
	# read each entry in jpilot pc3 to get record data
	my $success = read(FILE, $buf, 21);
	if(!($success)) {
		print "Cannot read pc3 file. Empty?: ".$pc3_file."\n";
		last;
	}
	my ($length,$ver,$rec,$id, $rt,$attr) = unpack("N N N N N c",$buf);
	if ($debug > 1) {
		print "PC3 record header\n";
		print "header length=".$length."\n";
		print "ver=".$ver."\n";
		print "rec length=".$rec."\n";
		print "id=".$id."\n";
		print "rt=".$rt."\n";
		print "attr=".$attr."\n";
		print "\n";
	}

	# read the actual record data blob
	$buf = undef;
	$success = read(FILE, $buf, $rec);
	die("Cannot seek file handle.") if not $success;
	if ($debug > 1) {
		print "Record Entry: ".$buf."\n";
		print "\n";
	}

	# Do not parse the record if it is a deleted entry
=pod
	From JPilot docs. SPENT_PC_RECORD_BIT == 256
	typedef enum {
		 PALM_REC = 100L,
		 MODIFIED_PALM_REC = 101L,
		 DELETED_PALM_REC = 102L,
		 NEW_PC_REC = 103L,
		 DELETED_PC_REC =  SPENT_PC_RECORD_BIT + 104L,
		 DELETED_DELETED_PALM_REC =  SPENT_PC_RECORD_BIT + 105L,
		 REPLACEMENT_PALM_REC = 106L
	} PCRecType;
	Take note that if record type is 106, that means the record in JPilot is 
	supposed to replace the one in the Palm
=cut	
	if ($rt) {
		# assign a record variable for each data blob
		my %record;
		# parse the data blob. Blob obtained from Palm::ToDo
		$record{PCRecType} = $rt;
		# parse the record attributes
		$record{id} = $id;
		$record{attributes}{expunged} = 1 if hex($attr) & 0x80;
		$record{attributes}{dirty} = 1    if hex($attr) & 0x40;
		$record{attributes}{deleted} = 1  if hex($attr) & 0x20;
		$record{attributes}{private} = 1  if hex($attr) & 0x10;
		$record{category} = 0;
		if ((hex($attr) & 0xa0) == 0) {
			$record{category} = hex($attr) & 0x0f;
		} else {
			$record{attributes}{archive} = 1 if hex($attr) & 0x08;
		}
		# parse the date
		my ($date, $priority) = unpack("n C", $buf);
		$buf = substr($buf, 3);

		if ($debug > 1) {
			print "Record Entry: ".$buf."\n";
			print "\n";
		}
		if ($date != 0xffff) {
			my $day;
			my $month;
			my $year;
			$day   =  $date       & 0x001f; # 5 bits
			$month = ($date >> 5) & 0x000f; # 4 bits
			$year  = ($date >> 9) & 0x007f; # 7 bits (years since 1904)
			$year += 1904;
			$record{due_day} = $day;
			$record{due_month} = $month;
			$record{due_year} = $year;
		}

		my $completed;  # Boolean
		$completed = $priority & 0x80;
		$priority &= 0x7f;      # Strip high bit
		$record{completed} = 1 if $completed;
		$record{priority} = $priority;

		my $description;
		my $note;
		($description, $note) = split /\0/, $buf;
		$record{description} = $description;
		$record{note} = $note unless $note eq "";
		if ($debug > 1) {
			print Dumper(\%record);
		}
		push(@pcrecords,\%record);
	}
	if (eof(FILE)) {
		last;
	}
}
close(FILE);

# jrecords to keep all records shown in jpilot interface
my @jrecords;
my @delrecords;

foreach $i (@pcrecords) {
	# print $i->{PCRecType}."\n";
	# Records to delete
	if ($i->{PCRecType} > 256 || $i->{PCRecType} == 102) {
		delete($i->{PCRecType});
		push(@delrecords, \$i)
	}
	# New record on PC
	if ($i->{PCRecType} == 103) {
		delete($i->{PCRecType});
		push(@jrecords, $i)
	}
	# Modified record on PC
	if ($i->{PCRecType} == 106) {
		delete($i{PCRecType});
		push(@jrecords, $i)
	}
}

my @append;
foreach $p (@{$pdb->{records}}) {
	my $exists = 0;
	foreach $i (@jrecords) {
		# print $p->{id} ." -> ".$i->{id}."\n";
		# record already exists as a modified record
		if ($p->{id} == $i->{id}) {
			$exists = 1;
			last;
		}
	}
	if ($exists == 0) {
		push(@append,$p);
	}
}
push(@jrecords,@append);

=pod
	CSV order in CSV export
	Category, Private, Indefinite, Due Date, Priority, Completed, ToDo Text, Note
=cut

open(FILE,">".$jpilot);
# print headers
print FILE "Category,Private,Indefinite,Due Date,Priority,Completed,ToDo Text,Note\n";
print "Category,Private,Indefinite,Due Date,Priority,Completed,ToDo Text,Note\n";
foreach (@jrecords) {
	my $csv = "";
	$csv .= "\"".&map_id2category($_->{category})."\","; # category exported as is
	$csv .= "\"".$i_->{private}."\",";										# private
	if ($_->{due_year}) {
		$csv .= "\"0\"".","."\"".$_->{due_year}."/".$_->{due_month}."/".$_->{due_day}."\","; # indefinite, due
	} else {
		$csv .= "\"1\"".","."\"\","; # indefinite, due
	}
	$csv .= "\"".$_->{priority}."\","; # priority
	$csv .= "\"".$_->{completed}."\","; # completed
	$csv .= "\"".$_->{description}."\","; # todo text
	$csv .= "\"".$_->{note}."\""; # note
	print FILE $csv."\n";
	print $csv."\n";
}
close(FILE);
