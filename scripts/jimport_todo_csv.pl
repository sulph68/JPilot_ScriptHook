#!/usr/bin/perl
my $debug = 0;

use Palm::ToDo;
use Data::Dumper;

my $import_file = $ENV{HOME}."/.jpilot/raw/todoist.csv";
my $pc3_file = $ENV{HOME}."/.jpilot/ToDoDB.pc3";
my $pdb_file = $ENV{HOME}."/.jpilot/ToDoDB.pdb";


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

# Get todoist ID from Notes record
sub get_id() {
	my ($s) = @_;
	$s=~m/\|\s+ID:\s+(\d+)\s+\|.*$/;
	my $id = $1;
	if ($debug > 1) {
		print "ID: ".$id."\n";
	}
	return $id;
}

sub pc3_pack_record() {
	my ($id, $rectype, $attr, $record) = @_;
	my $header_length = 21;
	my $version = 2;
	my $rec_length = length($record);
	# $id
	# $rectype
	# $attr
	my $packed = pack("N N N N N c", $header_length, $version, $rec_length, $id, $rectype, $attr);
}

sub pack_attributes() {
	my $cat 			= shift @_;
	my $priv			= shift @_;
	my $existing	= shift @_;
	my $packed_attr = 0;

	if ($existing) {
		# print "Copying existing attributes\n";
		if ($existing->{attributes}{expunged} || $existing->{attributes}{deleted}) {
			$packed_attr |= 0x08 if $existing->{attributes}{archive};
		} else {
			$packed_attr = ($existing->{category} & 0x0f);
		}
		$packed_attr |= 0x80 if $existing->{attributes}{expunged};
		$packed_attr |= 0x40 if $existing->{attributes}{dirty};
		$packed_attr |= 0x20 if $existing->{attributes}{deleted};
		$packed_attr |= 0x10 if $existing->{attributes}{private};

		$packed_attr |= 0x80 if $existing->{'attributes'}{'Delete'};
		$packed_attr |= 0x40 if $existing->{'attributes'}{'Dirty'};
		$packed_attr |= 0x20 if $existing->{'attributes'}{'Busy'};
		$packed_attr |= 0x10 if $existing->{'attributes'}{'Secret'};
	} else {
		$packed_attr = (int($cat) & 0x0f);
		$packed_attr |= 0x80 if (int($expunged) == 1);
		$packed_attr |= 0x40 if (int($dirty) == 1);
		$packed_attr |= 0x20 if (int($deleted) == 1);
		$packed_attr |= 0x10 if (int($priv) == 1);
	}
	if ($debug > 1) {
		print "Category: ".$cat."\n";
		print "Private: ".$priv."\n";
		print "Packed Attr: ".$packed_attr."\n";
	}
	return $packed_attr;
}

sub pack_todo_record() {
	my $cat				= shift @_;
	my $priv			= shift @_;
	my $indef			= shift @_;
	my $date 			= shift @_;
	my $priority 	= shift @_;
	my $completed	= shift @_;
	my $desc			= shift @_;
	my $note			= shift @_;

	# Pack referenced from Palm::ToDo
	my $rawDate = 0xffff;
	my ($y, $m, $d) = split("/",$date,3);
	if (int($d) != 0 && int($indef) == 0) {
		$rawDate = (int($d) & 0x001f) | ((int($m) & 0x000f) << 5) | (((int($y) - 1904) & 0x007f) << 9);
	}
	my $rawPriority = $priority & 0x7f;
	$rawPriority |= 0x80 if (int($completed) == 1);

	my $packed = pack("n C", $rawDate, $rawPriority);
	$packed .= $desc."\0";
	$packed .= $note."\0";
	return $packed;
}

# read all todo records from JPilot and resolve 
# return as an array of hash pointers to records
sub read_todo_jpilot() {
	my $pdb = Palm::ToDo->new;
	$pdb->Load($pdb_file);
	my @records = @{$pdb->{records}};

	my @pc_records = &read_todo_pc3();
	# sort largest to smallest ID
	@pc_records = sort{ $b->{id} <=> $a->{id} } @pc_records;

	my @return;
	my %temp;
	foreach my $palm (@records) {
		my $found  = 0;
		# find if a change was made on palm record on PC.
		foreach my $pc (@pc_records) {
			if ($palm->{id} eq $pc->{id}) {
				if ($found == 0) {
					$found = $pc;
				} elsif ($pc->{PCRecType} >= $found->{PCRecType}) {
print "compare found id: ".$pc->{id}." = ".$found->{id}." - ".$pc->{description}." - ".$found->{completed}."\n";
					$found = $pc;
				}
				$temp{$palm->{id}} = 1;
			}
		}
		if ($found == 0) {
			# no change on this palm record. Store to return
			push (@return, $palm);
		} else {
			# found some changes for this palm record. first found is the latest as list was reverse sorted
			push (@return, $found);
		}
	}
	foreach my $pc (@pc_records) {
		if ($temp{$pc->{id}} == 0) { 
			push (@return, $pc);
		}
	}
	return @return;
}

# read all records in todo PC3 file and return as a hash array
sub read_todo_pc3() {
	my @records;
	unless(open(FILE,$pc3_file)) {
		return @records;
	}
	binmode FILE;
	while (1) {
		my $buf = undef;
		# read each entry in jpilot pc3 to get record data
		my $success = read(FILE, $buf, 21);
		unless($success) { last; }
		die("Cannot seek file handle.") if not $success;
		my ($length,$ver,$rec,$id, $rt,$attr) = unpack("N N N N N c",$buf);
		# read the actual record data blob
		$buf = undef;
		$success = read(FILE, $buf, $rec);
		die("Cannot seek file handle.") if not $success;
    # parse the data blob. Blob obtained from Palm::ToDo
		# if PC rec that has been deleted, skip.
		if ($rt > 256) { 
			if (eof(FILE)) { last; }
			next;
		}
		my %record;
    $record{PCRecType} = $rt;
    # parse the record attributes
    $record{id} = $id;
    $record{category} = 0; # default to unfiled
    $record{attributes}{private} = 0; # default not private record
    $record{attributes}{expunged} = 1 if hex($attr) & 0x80;
    $record{attributes}{dirty} = 1    if hex($attr) & 0x40;
    $record{attributes}{deleted} = 1  if hex($attr) & 0x20;
    $record{attributes}{private} = 1  if hex($attr) & 0x10;
    if ((hex($attr) & 0xa0) == 0) {
      $record{category} = hex($attr) & 0x0f;
    } else {
      $record{attributes}{archive} = 1 if hex($attr) & 0x08;
    }
    # parse the date
    my ($date, $priority) = unpack("n C", $buf);
    $buf = substr($buf, 3);
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
    # parse blob
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
    push(@records,\%record);
		# exit loop if end of file
		if (eof(FILE)) { last; }
  }
	return @records;
}

sub generatePalmID() {
	# ID generation from Palm::PDB
	my $dmRecordIDReservedRange = 1;
	my $id = int(rand(100)) + 1;
	return ($dmRecordIDReservedRange + 1) << 12 if ($id & 0xFF000000);
}

##
# Main Code
##

unless(open(FILE,$import_file)) {
	print "Cannot find import file: ".$import_file."\n";
	exit 1;
}
my @import_data = <FILE>; shift @import_data; # remove first header row
chomp(@import_data);
close(FILE);

=pod
	CSV Header
	Category, Private, Indefinite, Due Date, Priority, Completed, ToDo Text, Note
=cut

my @jpilot_records = &read_todo_jpilot();

foreach $r (@import_data) {
	# Reading import from Todolist export
	# print $r."\n";
=pod
	typedef enum {
		 PALM_REC = 100L,
		 MODIFIED_PALM_REC = 101L,
		 DELETED_PALM_REC = 102L,
		 NEW_PC_REC = 103L,
		 DELETED_PC_REC =  SPENT_PC_RECORD_BIT + 104L,
		 DELETED_DELETED_PALM_REC =  SPENT_PC_RECORD_BIT + 105L,
		 REPLACEMENT_PALM_REC = 106L
	} PCRecType;
=cut
	my @record = split("\",\"",$r, 8);
	foreach my $i (@record) {
		$i=~s/(^\"|\"$)//g;
	}
	# Record originating from Todoist export will have a todoist id
	my $id = 0;
	my $rectype = 103; # default assume all todoist export items as new PC record
	my $found; # hold existing found record

	if (&get_id($record[-1]) > 0) {
		# search for record in PDB for the same Todoist ID to get the Palm ID
		foreach my $p (@jpilot_records) {
			if (&get_id($record[-1]) == &get_id($p->{note})) { # try to find if there is matching todoist ID
				$id = $p->{id};
				$found = $p;
				last;
			} elsif ($record[-2] eq $p->{description}) { # if not, try to find where descriptions are the same
				$id = $p->{id};
				$found = $p;
				last;
			}
		}
		# cannot find the Todoist ID in Palm PDB
		if ($debug > 1) {
				print Dumper(\@record);
				print Dumper(\$found);
		}
		if ($id == 0) { # new record for the palm. set as NEW_PC_REC
			$rectype = 103;
			$id = &generatePalmID();
		} else { # ID exists for palm is an existing record
			if ($record[5] == 1 && $found->{completed} == 1) { # both databases says item is done
				# do nothing. keep states
				print "ID (completed): ". $id." <-> ".&get_id($record[-1])."\n";
				next;
			} elsif ($record[5] == 1 && $found->{completed} == 0) { # todoist says done.
				# update record on palm
				$rectype = 106;
				print "Replacement palm record ID (completed): ". $id." <- ".&get_id($record[-1])."\n";
			} elsif ($record[5] == 0 && $found->{completed} == 1) { # Palm says done
				# do nothing. complete overrides
				print "ID (completed): ". $id." -> ".&get_id($record[-1])."\n";
				next;
			} elsif ($record[5] == 0 && $found->{completed} == 0) { # both are not done.
				# just perform a record update from todoist
				$rectype = 106;
				print "Replacement palm record ID (field update): ". $id." <- ".&get_id($record[-1])."\n";
			} else {
				# unknown state. don't do anything
				next;
			}
		}
	} else {
		# import record has no Todoist ID. Record did not come from Todoist export.
		# generate a new ID and place as a NEW_PC_REC
		$rectype = 103;
		$id = &generatePalmID();
	}
	if ($rectype == 106) {
		# as we are putting in a replacement record, delete the conflicting record from the palm mark as modified
		my @temp_record = @record;
		$temp_record[0] = $found->{category};
		$temp_record[1] = $found->{private};
		$temp_record[2] = 0 if $found->{due_day};
		$temp_record[3] = "";
		$temp_record[3] = $found->{due_year}."/".$found->{due_month}."/".$found->{due_day} if $found->{due_day};
		$temp_record[4] = $found->{priority};
		$temp_record[5] = $found->{completed};
		$temp_record[6] = $found->{description};
		$temp_record[7] = $found->{note};
		my $todo_attr 	= &pack_attributes(&map_category2id($temp_record[0]), int($temp_record[1]), $found);
		my $todo_rec 		= &pack_todo_record(@temp_record);
		my $pc3_header 	= &pc3_pack_record($id, 101, $todo_attr, $todo_rec);
		my $pc3_record 	= $pc3_header.$todo_rec;
		open(FILE,">>".$pc3_file);
		binmode FILE;
		print FILE $pc3_record;
		close(FILE);
	}
	my $todo_attr 	= &pack_attributes(&map_category2id($record[0]), int($record[1]), 0);
	my $todo_rec 		= &pack_todo_record(@record);
	my $pc3_header 	= &pc3_pack_record($id, $rectype, $todo_attr, $todo_rec);
	my $pc3_record 	= $pc3_header.$todo_rec;
	if ($debug > 1) {
		print "Todo Attr: ".$todo_attr."\n";
		print "Todo Rec: ".$todo_rec."\n";
		print "PC3 Hdr: ".$pc3_header."\n";
		print "PC3 Rec: ".$pc3_record."\n";
	}
	open(FILE,">>".$pc3_file);
	binmode FILE;
	print FILE $pc3_record;
	close(FILE);
}

exit 0;
