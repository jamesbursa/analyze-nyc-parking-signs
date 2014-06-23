#!/usr/bin/perl
#
# Analyze NYC parking sign data.
#
# The data is available at
# http://www.nyc.gov/html/dot/html/about/datafeeds.shtml#parking
# It should be placed in files locations.csv and signs.csv.
#

use strict;
use warnings;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use POSIX qw(strftime);

my ($CURB_LINE, $BUILDING_LINE,
		# these ordered from lowest to highest priority
		$FREE_PARKING, $METER_PARKING,
		$STREET_CLEANING, $NO_PARKING, $NO_STANDING, $NO_STOPPING,
		$BUS_STOP,
		# end special ordering
		$BUS_INFORMATION, $BLANK, $INFORMATION, $SPECIAL_INTEREST,
		$ANGLE_PARKING, $UNKNOWN_SIGN) = (0..20);
my @sign_type_name = qw/curb-line building-line
		parking-ok meter-parking
		street-cleaning no-parking no-standing no-stopping
		bus-stop
		bus-info blank information special-interest
		angle-parking unknown/;
my %boro_name = qw/B Bronx K Brooklyn M Manhattan Q Queens S Staten/;
my $PARKING_SPACE_LENGTH = 20;  # ft
my $PARKING_SPACE_WIDTH = 10;   # ft

my $VERBOSE = 0;
my $log_name = strftime("analyze_%Y%m%d_%H%M%S.log", gmtime);
open my $log_fh, ">", $log_name
		or die "Failed to open $log_name for writing: $!\n";
print_log("Logging to %s\n", $log_name);

my %desc_count;
my %block_count;
my %block_to_sign;
my %block_to_street;
my %block_to_from;
my %block_to_to;
my %block_to_side;
load_signs("signs.csv");
load_locations("locations.csv");

my %sign_meaning;
my %sign_details;
parse_sign_descriptions();

my $parking_fact_fh;
my $block_dimension_fh;
my $regulation_dimension_fh;
my $regulation_time_dimension_fh;
open_output_files();

my $total_cars;
my %block_db_id;
my $max_block_db_id = 0;
my %regulation_db_id;
my $max_regulation_db_id = 0;
#analyze_block("MS-026823");
#analyze_block("MS-026831");
#analyze_block("MS-026538");
#analyze_block("MS-297560");
#analyze_block("MS-239742");
#analyze_block("MS-239744");
#analyze_block("MS-241951");
analyze_blocks();

print_log("%10i total car spaces", $total_cars);
print_log("%10i rows in block_dimension", $max_block_db_id);
print_log("%10i rows in regulation_dimension", $max_regulation_db_id);


#
# Load sign records from CSV file.
#
sub load_signs {
	my $signs_csv = shift;
	my %boro_count;
	my $total_count = 0;

	print_log("Loading signs from $signs_csv");

	open my $signs_fh, "<", $signs_csv
			or die "Failed to open $signs_csv: $!\n";
	while (my $line = <$signs_fh>) {
		$line =~ s/^\xef\xbb\xbf//;  # remove BOM
		$line =~ s/[\r\n]+$//;
		my ($boro, $order, $seq, $ft, $arrow, $desc) = split /,/, $line;
		my $block = $boro.$order;
		$seq = int $seq;
		$arrow =~ s/ +//g;
		$desc =~ s/ +$//g;
		$total_count++;
		$boro_count{$boro}++;
		$desc_count{$desc}++;
		$block_count{$block}++;
		$block_to_sign{$block}{$seq} = "$ft,$arrow,$desc";
	}
	close $signs_fh;

	print_log("Record counts by borough:");
	foreach my $boro (sort keys %boro_count) {
		print_log("%10i %-5s", $boro_count{$boro}, $boro_name{$boro});
	}
	print_log("%10i total", $total_count);

	print_log("Number of block ids with signs:     %10i",
			scalar (keys %block_count));
	print_log("Number of sign types:               %10i",
			scalar (keys %desc_count));
	print_log("");
}


#
# Load location records from CSV file.
#
sub load_locations {
	my $locations_csv = shift;

	print_log("Loading locations from $locations_csv");

	open my $locations_fh, "<", $locations_csv
			or die "Failed to open $locations_csv: $!\n";
	while (my $line = <$locations_fh>) {
		$line =~ s/^\xef\xbb\xbf//;  # remove BOM
		$line =~ s/[\r\n]+$//;
		my ($boro, $order, $street,
				$from, $to, $side) = split /,/, $line;
		my $block = $boro.$order;
		$street =~ s/ +/ /g;
		$from =~ s/ +/ /g;
		$to =~ s/ +/ /g;
		$block_to_street{$block} = $street;
		$block_to_from{$block} = $from;
		$block_to_to{$block} = $to;
		$block_to_side{$block} = $side;
	}
	close $locations_fh;
	print_log("Number of block ids with locations: %10i",
			scalar (keys %block_to_street));
	print_log("");
}


#
# Attempt to parse each distinct sign text.
#
sub parse_sign_descriptions {
	my $fully_parsed = 0;
	my $partly_parsed = 0;
	my $unknown_sign = 0;
	my $fully_parsed_count = 0;
	my $partly_parsed_count = 0;
	my $unknown_sign_count = 0;
	my %type_count;
	my %type_count_count;

	print_log("Parsing %i sign descriptions", scalar (keys %desc_count));

	foreach my $sign (sort keys %desc_count) {
		my ($type, $desc, @details) = parse_description($sign);
		if ($VERBOSE) {
			print_log("%-16s (%-14s) %5i \"%s\" ...\"%s\"",
					$sign_type_name[$type],
					(join ",", @details),
					$desc_count{$sign}, $sign,
					$desc);
		}
		if ($type == $UNKNOWN_SIGN) {
			$unknown_sign++;
			$unknown_sign_count += $desc_count{$sign};
#			print_log("<$type> @details \"...$desc\" ");
#			print_log("%10i  %s", $desc_count{$sign}, $sign);
		} elsif ($desc ne "") {
			$partly_parsed++;
			$partly_parsed_count += $desc_count{$sign};
		} else {
			$fully_parsed++;
			$fully_parsed_count += $desc_count{$sign};
		}
		$type_count{$type}++;
		$type_count_count{$type} += $desc_count{$sign};

		$sign_meaning{$sign} = $type;
		$sign_details{$sign} = join ",", @details;
	}

	print_log("Fully parsed:  %10i %10i",
			$fully_parsed, $fully_parsed_count);
	print_log("Partly parsed: %10i %10i",
			$partly_parsed, $partly_parsed_count);
	print_log("Unknown:       %10i %10i",
			$unknown_sign, $unknown_sign_count);

	print_log("By type:");
	foreach my $type (sort { $a <=> $b } keys %type_count) {
		print_log("%10i %10i %10i  %s", $type, $type_count{$type},
		       $type_count_count{$type}, $sign_type_name[$type]);
	}

	print_log("");
}


sub parse_description {
	my $desc = shift;

	my $type = $UNKNOWN_SIGN;
	my $t0 = 0;
	my $t1 = 0;
	my @details = ();

	# typo corrections
	$desc =~ s/NP PARKING/NO PARKING/g;
	$desc =~ s/ F RI / FRI /g;
	$desc =~ s/HOILDAY/HOLIDAY/g;
	$desc =~ s/SIGNLE/SINGLE/g;
	$desc =~ s/SYBBOL/SYMBOL/g;
	$desc =~ s/BROON /BROOM /g;
	$desc =~ s/BRROM /BROOM /g;
	$desc =~ s/PARKIGN/PARKING/g;
	$desc =~ s/PKNG/PARKING/g;
	$desc =~ s/12 NOON/NOON/g;
	$desc =~ s/SANI-TATION/SANITATION/g;
	$desc =~ s/NOON 1:3-PM/NOON TO 1:30PM/g;
	$desc =~ s/8AM 11AM/8AM TO 11AM/g;
	$desc =~ s/^NO PARKING \(SANITATION BROOM SYMBOL\) 9-10:30AM W\/SINGLE ARROW$/NO PARKING (SANITATION BROOM SYMBOL) 9-10:30AM THURS W\/SINGLE ARROW/g;
	$desc =~ s/^NO PARKING \(SANITATION BROOM SYMBOL\) 7:30-8AM W\/SINGLE ARROW/NO PARKING (SANITATION BROOM SYMBOL) 7:30-8AM WED W\/SINGLE ARROW/g;

	# noise and comments
	$desc =~ s/\(?SUPE?RSEDE.*//g;
	$desc =~ s/\(?REPLACE.*//g;
	$desc =~ s/\(USE .*//g;
	$desc =~ s/\(SEE .*//g;
	$desc =~ s/\(NOTE.*//g;
	$desc =~ s/\(DO NOT USE.*//g;
	$desc =~ s/\(?REVISED.*//g;
	$desc =~ s/\(? ?SIGN TO BE .*//g;
	$desc =~ s/SEE [^ ]+$//g;
	$desc =~ s/\(DON'T LITTER\) *//g;
	$desc =~ s/<?-+>//g;
	$desc =~ s/W?\/? *\(?(SINGLE )?(HEAD )?ARROW\)?//g;
	$desc =~ s/BUS LAYOVER AREA //g;

	$desc =~ s/ +$//g;

	if ($desc eq "Curb Line") {
		$type = $CURB_LINE;
		$desc = "";
	} elsif ($desc eq "Building Line" or $desc eq "Property Line") {
		$type = $BUILDING_LINE;
		$desc = "";
	} elsif ($desc =~ /^NIGHT REGULATION */gci) {
		($type, $desc, @details) = parse_night_regulation($');
	} elsif ($desc =~ /^NO PARKING */gci) {
		($type, $desc, @details) = parse_no_parking($');
	} elsif ($desc =~ /^NO STANDING */gci) {
		($type, $desc, @details) = parse_no_standing($');
	} elsif ($desc =~ /^NO STOPPING */gci) {
		($type, $desc, @details) = parse_no_stopping($');
	} elsif ($desc =~ /^BUS STOP */gci) {
		($type, $desc, @details) = parse_bus_stop($');
	} elsif ($desc =~ /^M 18 LTD */gci or
			$desc =~ /^14 STREET & UNION SQ */gci or
			$desc =~ /^X 14 */gci) {
		$type = $BUS_INFORMATION;
		$desc = "";
	} elsif ($desc =~
	/^([0-9\/]+) *H(OU)?R\.? *(METERED|MUNI-METER)? *PARKING */gci or
			$desc =~ /^([0-9\/]+) *HMP */gci) {
		my $mins;
		if ($1 eq "1/2") {
			$mins = 30;
		} else {
			$mins = 60 * $1;
		}		
		($type, $desc, @details) = parse_meter_parking($');
		push @details, $mins;
	} elsif ($desc =~ /^PAY AT MUNI-METER/gci or
			$desc =~ /^NYC PARKING CARD AVAILABLE/gci) {
		$type = $INFORMATION;
		$desc = "";
	} elsif ($desc eq "") {
		$type = $BLANK;
	} elsif ($desc =~
	/^((BACK|HEAD) IN )?(ANGLE|.. \(?DEGREE\)?) PARKING/gci) {
		$type = $ANGLE_PARKING;
		$desc = "";
	} elsif ($desc =~ /DEPARTMENT|DEPT|OFFICE|VEHICLES|JUDGE|FACULTY/gci or
			$desc =~ /POLICE|COURT|COMMISSION|FUNERAL|DOCTOR/gci or
			$desc =~ /JUSTICE|PROSECUTOR|AUTHORITY|CLERK|DHS/gci or
			$desc =~ /STATE|NYS|FEDERAL|COLLEGE|BUREAU|MAYOR/gci or
			$desc =~ /CITY HALL|AMBULANCE|AMBULETTE|BOARD OF/gci or
			$desc =~ /N Y S|MAIL/gci) {
		$type = $SPECIAL_INTEREST;
		$desc =~ s/EXCEPT *//g;
		$desc =~ s/ *ONLY//g;
		@details = ($desc);
		$desc = "";
	}

	return $type, $desc, @details;

	#print_log("\n");
}


sub parse_night_regulation {
	my $desc = shift;
	if ($desc =~ /^\((HALF )?MOON ?[&\/] ?STARS? SYMBOLS?\) */gci) {
		$desc = $';
	}
	if ($desc =~ /^NO PARKING */gci) {
		return parse_no_parking($');
	} elsif ($desc =~ /^\((SANITATION )?BROOM SYMBOL\) */gci) {
		return parse_no_parking($');
	}
	return $UNKNOWN_SIGN, $desc, ();
}


sub parse_no_parking {
	my $desc = shift;
	my $type = $NO_PARKING;
	if ($desc =~ /^\((SANITATION )?BROOM SYMBOL\) */gci or
			$desc =~ /^\(SANITATION SYMBOL\) */gci) {
		$type = $STREET_CLEANING;
		$desc = $';
	}
	if ($desc =~ /^\(MOON\/STARS SYMBOLS\) */gci) {
		$desc = $';
	}
	if ($desc =~ /^W\/ MOON & STARS SYMBOLS */gci) {
		$desc = $';
	}
	if ($desc =~ /^NO PARKING */gci) {
		$desc = $';
	}
	my ($rest, @times) = parse_time_periods($desc);
	return $type, $rest, @times;
}


sub parse_no_standing {
	my $desc = shift;
	if ($desc =~ /^HANDICAP BUS/) {
		return $BUS_STOP, "", ();
	}
	my ($rest, @times) = parse_time_periods($desc);
	return $NO_STANDING, $rest, @times;
}


sub parse_no_stopping {
	my $desc = shift;
	my ($rest, @times) = parse_time_periods($desc);
	return $NO_STOPPING, $rest, @times;
}


sub parse_bus_stop {
	return $BUS_STOP, "", ();
}


sub parse_meter_parking {
	my $desc = shift;
	my ($rest, @times) = parse_time_periods($desc);
	return $METER_PARKING, $rest, @times;
}


sub parse_time_periods {
	my $desc = shift;
	if ($desc =~ /^ANYTIME */gci) {
		my $t0 = 0;
		my $t1 = 24 * 60;
		my $res = "";
		for (my $z = 0; $z != 7; $z++) { (vec $res, $z, 1) = 1; }
		return $', $t0, $t1, $res;
	} else {
		my ($rest, $t0, $t1) = parse_time($desc);
		my $days;
		if ($rest eq $desc) {
			# no time parsed: try day, time
			($rest, $days) = parse_day($rest);
			($rest, $t0, $t1) = parse_time($rest);
		} else {
			# time, day
			($rest, $days) = parse_day($rest);
		}
		return $rest, $t0, $t1, $days;
	}
	return $desc, ();
}


sub parse_time {
	my $desc = shift;
	my $t0 = 0;
	my $t1 = 24 * 60;
	my $time_regex = "((\\d\\d?)(:(\\d\\d))? *([AP]M)?|NOON|MIDNIGHT)";

	if ($desc =~ /^$time_regex *(-|TO|TO-) *$time_regex */gci) {
		if ($7 eq "NOON") {
			$t1 = 12 * 60;
		} elsif ($7 eq "MIDNIGHT") {
			$t1 = 0;
		} else {
			$t1 = $8 * 60;
			$t1 = 0 if $8 == 12;
			$t1 += $10 if $10;
			$t1 += (12 * 60) if $11 eq "PM";
		}
		if ($1 eq "NOON") {
			$t0 = 12 * 60;
		} elsif ($1 eq "MIDNIGHT") {
			$t0 = 0;
		} else {
			$t0 = $2 * 60;
			$t0 = 0 if $2 == 12;
			$t0 += $4 if $4;
			if ($5) {
				$t0 += (12 * 60) if $5 eq "PM";
			} else {
				$t0 += (12 * 60) if 12 * 60 <= $t1;
			}
		}
		#print_log("%.2i:%.2i-%.2i:%.2i ",
		#       $t0 / 60, $t0 % 60, $t1 / 60, $t1 % 60);
		return ($', $t0, $t1);
	}

	return $desc, $t0, $t1;
}


sub parse_day {
	my $desc = shift;

	my @day_names = qw/SUN MON TUE WED THU FRI SAT/;
	my $res = "";
	for (my $z = 0; $z != 7; $z++) { (vec $res, $z, 1) = 0; }
	my $no_days = $res;

	my $except = 1;
	if ($desc =~ /^EXCEPT */gci) {
		$except = 0;
		$desc = $';
		for (my $z = 0; $z != 7; $z++) { (vec $res, $z, 1) = 1; }
	}

	if ($desc =~ /^INCLUDING SUNDAY */gci) {
		$desc = $';
		for (my $z = 0; $z != 7; $z++) { (vec $res, $z, 1) = 1; }
		return $desc, $res;
	}

	my $last_day;
	my $go = 1;
	while ($go) {
#print_log("<$desc>");
		$go = 0;
		for (my $dow = 0; $dow != 7; $dow++) {
			my $name = $day_names[$dow];
			if ($desc =~ /^${name}[A-Z]*[.]? */gci) {
				(vec $res, $dow, 1) = $except;
				$last_day = $dow;
				$desc = $';
				$go = 1;
			}
		}
		if ($desc =~ /^(THRU|-) */gci) {
			$desc = $';
			for (my $dow = 0; $dow != 7; $dow++) {
				my $name = $day_names[$dow];
				if ($desc =~ /^${name}[A-Z]*[.]? */gci) {
					for (my $z = $last_day; $z <= $dow;
							$z++) {
						(vec $res, $z, 1) = $except;
					}
					$desc = $';
					$go = 1;
					next;
				}
			}
		}
		if ($desc =~ /^\& */gci) {
			$desc = $';
			$go = 1;
		}
		if ($desc =~ /^SCHOOL DAYS */gci) {
			for (my $z = 1; $z <= 5; $z++) {
				(vec $res, $z, 1) = $except;
			}
			$desc = $';
			$go = 1;
		}
	}

	#print_log("d");
	#for (my $z = 0; $z <= 6; $z++) {
	#	print "$z" if $res[$z];
	#}

	if ($res eq $no_days) {
		# no days specified means it applies everyday
		for (my $z = 0; $z != 7; $z++) { (vec $res, $z, 1) = 1; }
	}

	return $desc, $res;
}


#
# Open output files for writing.
#
sub open_output_files {
	open $parking_fact_fh, ">", "parking_fact"
			or die "Failed to open parking_fact: $!\n";
	open $block_dimension_fh, ">", "block_dimension"
			or die "Failed to open block_dimension: $!\n";
	open $regulation_dimension_fh, ">", "regulation_dimension"
			or die "Failed to open regulation_dimension: $!\n";
	open $regulation_time_dimension_fh, ">", "regulation_time_dimension"
			or die "Failed to open regulation_time_dimension: $!\n";
}


#
# Analyze all the blocks.
#
sub analyze_blocks {
	my $block_count = scalar (keys %block_count);
	print_log("Analyzing %i blocks...", $block_count);

	my $done = 0;
	my $total_length = 0;
	foreach my $block (keys %block_count) {
		$total_length += analyze_block($block);
		$done++;
		print_log("Processed %5i/%5i blocks (%4.1f%%) [%7i km]",
		       $done, $block_count, 100.0 * $done / $block_count,
		       ft_to_km($total_length))
			       if ($done % 1000) == 0;
		#last if $done == 100;
	}

	print_log("Total block length: %10i ft %10.1f km", $total_length,
	       ft_to_km($total_length));
	print_log("");
}


#
# Analyze the signs on a single block side to determine the rules.
#
sub analyze_block {
	my $id = shift;

	if ($VERBOSE) {
		print_log("=== %s ===", $id);
		print_log("%s (%s to %s) %s", $block_to_street{$id},
				$block_to_from{$id}, $block_to_to{$id},
				$block_to_side{$id});
	}

	# copy signs for this block to @data for convenience
	my @data;
	foreach my $seq (keys %{$block_to_sign{$id}}) {
		my ($ft, $arrow, $desc) = split /,/, $block_to_sign{$id}{$seq};
		$ft = int $ft;
		push @data, [$ft, $seq, $arrow, $desc];
	}
	# sort by position (ft) and then by sequence
	@data = sort { ($a->[0] <=> $b->[0]) || ($a->[1] <=> $b->[1]) } @data;

	for (my $z = 0; $z < scalar @data; $z++) {
		print_log("%10i %10i %5s %s", @{$data[$z]}) if $VERBOSE;
		$data[$z]->[1] = $sign_meaning{$data[$z]->[3]};
		$data[$z]->[3] = $sign_details{$data[$z]->[3]};
	}

	# data now contains: ft, meaning, arrow, details
	#print_log("    =>");
	#for (my $z = 0; $z < scalar @data; $z++) {
	#	print_log("    %10i %-20s %5s %s",
	#	       $data[$z]->[0], $sign_type_name[$data[$z]->[1]],
	#	       $data[$z]->[2], $data[$z]->[3];
	#}

	if ($VERBOSE and ($data[0]->[0] != 0 or $data[0]->[1] != $CURB_LINE)) {
		print_log("Warning: block %s starts with %i " .
			"%s instead of 0 Curb Line",
			$id, $data[0]->[0], $sign_type_name[$data[0]->[1]]);
	}
	if ($VERBOSE and $data[-1]->[1] != $CURB_LINE) {
		print_log("Warning: block %s ends with %i %s " .
			"instead of Curb Line",
			$id, $data[-1]->[0], $sign_type_name[$data[-1]->[1]]);
	}

	my $block_length = $data[-1]->[0];
	print_log("Length: %i ft", $block_length) if $VERBOSE;

	compute_arrow_directions(\@data);
	if ($VERBOSE) {
		print_log("=>");
		for (my $z = 0; $z < scalar @data; $z++) {
			print_log("%10i %-20s %5s %s",
			       $data[$z]->[0], $sign_type_name[$data[$z]->[1]],
			       $data[$z]->[2], $data[$z]->[3]);
		}
	}

	my @segments;
	for (my $z = 0; $z < scalar @data; $z++) {
		my ($ft, $type, $arrow, $details) = @{$data[$z]};
		next if $type == $CURB_LINE;
		next if $type == $BUILDING_LINE;
		next if $type == $BUS_INFORMATION;
		next if $type == $INFORMATION;
		if ($arrow == -1) {
			# arrow backwards
			my $start = extend_sign_decree(-1, \@data, $z,
					$block_length);
			push @segments, [$start, $ft, $type, $details];
		} elsif ($arrow == +1) {
			# arrow forwards
			my $end = extend_sign_decree(+1, \@data, $z,
					$block_length);
			push @segments, [$ft, $end, $type, $details];
		} else {
			# no arrow - extends both ways
			my $start = extend_sign_decree(-1, \@data, $z,
					$block_length);
			my $end = extend_sign_decree(+1, \@data, $z,
					$block_length);
			push @segments, [$start, $end, $type, $details];
		}
	}

	# sort segments so that we can uniq
	@segments = sort { $a->[0] <=> $b->[0] or
		$a->[1] <=> $b->[1] or
		$a->[2] <=> $b->[2] or
		$a->[3] cmp $b->[3] } @segments;

	# remove exact duplicates
	my @uniq_segments;
	if (1 <= scalar @segments) {
		push @uniq_segments, $segments[0];
		for (my $z = 1; $z < scalar @segments; $z++) {
			if ($segments[$z]->[0] != $segments[$z-1]->[0] or
			    $segments[$z]->[1] != $segments[$z-1]->[1] or
			    $segments[$z]->[2] != $segments[$z-1]->[2] or
			    $segments[$z]->[3] ne $segments[$z-1]->[3]) {
				push @uniq_segments, $segments[$z];
			}
		}
	}

	if ($VERBOSE) {
		print_log("=>");
		for (my $z = 0; $z < scalar @uniq_segments; $z++) {
			print_log(" [%3i] %5i-%5i %-20s %s",
			       $z, $uniq_segments[$z]->[0],
			       $uniq_segments[$z]->[1],
			       $sign_type_name[$uniq_segments[$z]->[2]],
			       $uniq_segments[$z]->[3]);
		}
		print_log("=>");
	}

	# convert sign decrees into non-overlapping segments of merged rules
	my @current = ();
	my $pos = 0;
	for (my $z = 0; $z <= @uniq_segments; $z++) {
		my $start = 1000000;
		$start = $uniq_segments[$z]->[0] if $z < @uniq_segments;
		#print_log("z %i, start %i, current (%s)", $z, $start,
		#		(join ", ", @current));
		my $min_end = min(map { $uniq_segments[$_]->[1] } @current);
		while (@current and $min_end <= $start) {
			print_log("A %5i-%5i: (%s)", $pos, $min_end,
					(join ", ", @current)) if $VERBOSE;
			output_segment($id, $pos, $min_end,
					(@uniq_segments)[@current]);
			$pos = $min_end;
			@current = grep { $uniq_segments[$_]->[1] != $pos }
					@current;
			$min_end = min(map { $uniq_segments[$_]->[1] }
					@current);
		}
		if (@current and $pos < $start) {
			print_log("B %5i-%5i: (%s)", $pos, $start,
					(join ", ", @current)) if $VERBOSE;
			output_segment($id, $pos, $start,
					(@uniq_segments)[@current]);
		}
		push @current, $z if $z < @uniq_segments;
		$pos = $start;
	}

	print_log("") if $VERBOSE;

	return $block_length;
}


sub output_segment {
	my ($block, $start, $end, @decrees) = @_;
	my $length = $end - $start;
	my $cars = int ($length / $PARKING_SPACE_LENGTH);

	if ($length == 0) {
		print_log("Warning: segment of length 0 at offset %i " .
				"in block %s (%s - %s) %s",
				$start, $block_to_street{$block},
				$block_to_from{$block}, $block_to_to{$block},
				$block_to_side{$block}) if $VERBOSE;
		return;
	}

	my @half_hours = ($FREE_PARKING) x (7 * 48);
	my $special_interest = "";
	my $angle_parking = 0;
	foreach my $decree (@decrees) {
		my $type = $decree->[2];
		my $details = $decree->[3];
		if ($type == $METER_PARKING or
				$type == $NO_PARKING or
				$type == $STREET_CLEANING or
				$type == $NO_STANDING or
				$type == $NO_STOPPING) {
			my ($t0, $t1, $days) = split /,/, $details;
			for (my $z = 0; $z != 7; $z++) {
				next unless vec $days, $z, 1;
				for (my $half_hr = $t0 / 30;
						$half_hr < $t1 / 30;
						$half_hr++) {
					my $h = $z * 48 + $half_hr;
					$half_hours[$h] = $type
						if $half_hours[$h] < $type;
				}
			}
		} elsif ($type == $BUS_STOP) {
			@half_hours = ($BUS_STOP) x (7 * 48);
		} elsif ($type == $SPECIAL_INTEREST) {
			$special_interest = $details;
		} elsif ($type == $ANGLE_PARKING) {
			$angle_parking = 1;
			$cars = int ($length / $PARKING_SPACE_WIDTH);
		}
	}

	my @hours_by_type = (0) x 10;
	foreach my $half_hour (@half_hours) {
		$hours_by_type[$half_hour] += 0.5;
	}

	my $regulation = join "\t",
	   $hours_by_type[$FREE_PARKING],
	   $hours_by_type[$METER_PARKING],
	   $hours_by_type[$STREET_CLEANING],
	   $hours_by_type[$NO_PARKING],
	   $hours_by_type[$NO_STANDING],
	   $hours_by_type[$NO_STOPPING],
	   $hours_by_type[$BUS_STOP],
	   $angle_parking,
	   $special_interest;
	my $regulation_key = $regulation . "\t" . (join "\t", @half_hours);

	output_block($block) unless exists $block_db_id{$block};
	output_regulation($regulation_key, $regulation, \@half_hours)
			unless exists $regulation_db_id{$regulation_key};

	printf $parking_fact_fh "%i\t%i\t%i\t%i\t%i\t%g\n",
	       $block_db_id{$block}, $regulation_db_id{$regulation_key},
	       $start, $length, $cars,
	       $cars * ($hours_by_type[$FREE_PARKING] +
			       $hours_by_type[$METER_PARKING]) / (7 * 24.0);
	$total_cars += $cars;

	print_log("* %s %i +%i (%i cars) %s", $block, $start, $length,
			$cars, (join ",",
				map { $sign_type_name[$_->[2]] } @decrees))
		if $VERBOSE;
}


sub output_block {
	my $block = shift;
	$max_block_db_id++;
	$block_db_id{$block} = $max_block_db_id;
	printf $block_dimension_fh "%i\t%s\t%s\t%s\t%s\t%s\n",
	       $max_block_db_id,
	       $boro_name{substr $block, 0, 1},
	       $block_to_street{$block},
	       $block_to_from{$block},
	       $block_to_to{$block},
	       $block_to_side{$block};
}


sub output_regulation {
	my ($regulation_key, $regulation, $half_hours) = @_;
	$max_regulation_db_id++;
	$regulation_db_id{$regulation_key} = $max_regulation_db_id;
	printf $regulation_dimension_fh "%i\t%s\n",
	       $max_regulation_db_id,
	       $regulation;
	for (my $z = 0; $z != @$half_hours; $z++) {
		my $day_of_week = int ($z / 48);
		my $half_hour = $z % 48;
		my $rule = $half_hours->[$z];
		printf $regulation_time_dimension_fh
			"%i\t%i\t%i\t%i\t%i\t%i\t%i\n",
			$max_regulation_db_id,
			$day_of_week, $half_hour,
			$rule == $FREE_PARKING,
			$rule == $METER_PARKING,
			$rule == $STREET_CLEANING,
			($rule == $NO_PARKING or
				$rule == $NO_STANDING or
				$rule == $NO_STOPPING or
				$rule == $BUS_STOP);
	}
}


sub compute_arrow_directions {
	my $data = shift;

	my $way = 0; # +1: N or W is positive ft
		     # -1: S or E is positive ft

	# search for matching pairs of signs to determine arrow direction
	for (my $z = 0; $way == 0 and $z < scalar @$data; $z++) {
		my ($ft, $type, $arrow, $details) = @{$data->[$z]};
		next if $type == $CURB_LINE;
		next if $type == $BUILDING_LINE;
		next if $type == $BUS_INFORMATION;
		next if $type == $INFORMATION;
		for (my $y = $z + 1; $y < scalar @$data; $y++) {
			my ($ft2, $type2, $arrow2, $details2) = @{$data->[$y]};
			next if $ft == $ft2;
			last if $arrow2 eq $arrow;
			if ($type == $type2 and $details eq $details2) {
				if ($arrow eq "" and $arrow2 ne "") {
					# <->     <-- 
					if ($arrow2 eq "N" or $arrow2 eq "W") {
						$way = -1;
					} else {
						$way = +1;
					}
					last;
				} elsif ($arrow ne "" and $arrow2 eq "") {
					# -->     <->
					if ($arrow eq "N" or $arrow eq "W") {
						$way = +1;
					} else {
						$way = -1;
					}
					last;
				} elsif ($arrow ne "" and $arrow2 ne "") {
					# -->     <--
					if ($arrow eq "N" or $arrow eq "W") {
						$way = +1;
					} else {
						$way = -1;
					}
					last;
				}
			}
		}
	}

	if ($way == 0) {
		# fallback to a sign at the start
		for (my $z = 0; $z < scalar @$data; $z++) {
			my ($ft, $type, $arrow, $details) = @{$data->[$z]};
			next if $type == $CURB_LINE;
			next if $type == $BUILDING_LINE;
			next if $type == $BUS_INFORMATION;
			next if $type == $INFORMATION;
			last if $arrow eq "";
			# |       <--
			if ($arrow eq "N" or $arrow eq "W") {
				$way = -1;
			} else {
				$way = +1;
			}
			last;
		}
	}

	if ($way == 0) {
		# fallback to a sign at the end
		for (my $z = @$data - 1; 0 <= $z; $z--) {
			my ($ft, $type, $arrow, $details) = @{$data->[$z]};
			next if $type == $CURB_LINE;
			next if $type == $BUILDING_LINE;
			next if $type == $BUS_INFORMATION;
			next if $type == $INFORMATION;
			last if $arrow eq "";
			# -->       |
			if ($arrow eq "N" or $arrow eq "W") {
				$way = +1;
			} else {
				$way = -1;
			}
			last;
		}
	}

	# just guess
	if ($way == 0) {
		print_log("unable to compute arrow directions") if $VERBOSE;
		$way = -1;
	}

	print_log("arrow direction: $way") if $VERBOSE;

	for (my $z = 0; $z < scalar @$data; $z++) {
		my $arrow = $data->[$z]->[2];
		if ($arrow eq "N" or $arrow eq "W") {
			$arrow = $way;
		} elsif ($arrow eq "S" or $arrow eq "E") {
			$arrow = -$way;
		} else {
			$arrow = 0;
		}
		$data->[$z]->[2] = $arrow;
	}
}


sub extend_sign_decree {
	my ($dirn, $data, $y, $block_length) = @_;
	my ($ft, $type, $arrow, $details) = @{$data->[$y]};

	die "dirn must be ±1" unless abs $dirn == 1;

	my $end = $ft;

	# skip all other signs at the same position
	while ($data->[$y]->[0] == $ft) {
		$y += $dirn;
		return 0 if $y < 0;
		return $block_length if @$data <= $y;
	}

	while (0 <= $y and $y < scalar @$data) {
		my $new_ft = $data->[$y]->[0];
		my $found_duplicate = 0;
		my $arrow_duplicate = 0;
		while (0 <= $y and $y < scalar @$data and
				$data->[$y]->[0] == $new_ft) {
			if ($data->[$y]->[1] == $type and
			    $data->[$y]->[3] eq $details) {
				$found_duplicate = 1;
				$arrow_duplicate = $data->[$y]->[2];
			}
			$y += $dirn;
		}
		return $new_ft unless $found_duplicate;
		return $new_ft if $arrow_duplicate == -$dirn;
	}

	return 0 if $y < 0;
	return $block_length;
}


sub ft_to_km {
	my $ft = shift;
	return $ft * 0.3048 * 0.001;
}


sub print_log {
	my $message = shift;
	if ($message eq "\n" or $message eq "") {
		print "\n";
		return;
	}
	my $now = strftime("%F %T", gmtime);
	#my $size = (`ps -o size= $$` / 1024);
	if (@_) {
		$message = sprintf $message, @_;
	}
	printf "[%s] %s\n", $now, $message;
	printf $log_fh "[%s] %s\n", $now, $message;
	#printf "[%s] (%iM) %s\n", $now, $size, $message;
}

