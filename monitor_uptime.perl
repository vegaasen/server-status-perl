#!/usr/bin/perl

#
# Simple perl-script that does the following:
# -reads a domain-list that just issues a request to wherever specified. Then, it will just output this stuff to a specified file + 
# as output, mimc'd through a html-page with page-reload.
# 
# @author vegaasen
#

use warnings;
use strict;
use Tie::File;
use LWP::UserAgent;

my $error_log  = 'uptime.err';
my $domains = 'domain.list';

my $response_limit = 5; 
my $consolePrint = 1;

die "File $domains is not exist\n" unless (-e $domains);
my $localtime     = localtime;
my @serverStatuses; # currently, jeah this is the name. will be an object in the end. However not now.
my @errors;
my ($day,$month,$date,$hour,$year) = split /\s+/,scalar localtime;
my $output_file = 'report-'.$date.'.'.$month.'.'.$year.'.out';
my (@all_addr) = ();
tie @all_addr, 'Tie::File', $domains or error("Cant open file {$domains} to read the list of domains");

if (-e $output_file) {
   open(OUT,">> $output_file") 
	  or error("Cant append to existing file $output_file");
} else {
   open(OUT,"> $output_file") 
	  or error("Cant write to file $output_file");
}

sub checkAddresses() {
	print OUT "\n+" .('-' x 84) . "+\n";
	print OUT   "|", ' ' x 30,"Time: $hour",' ' x 40,"|\n";
	print OUT   "|",' 'x 10,'HOST',' ' x 37,'STATUS',' ' x 7, "RESPONSE            |\n";
	print OUT   "+" .('-' x 84) . "+\n";
	for (0 .. $#all_addr) {
	 chop $all_addr[$_] if ($all_addr[$_] =~ /\s+$/);
	 next if ($all_addr[$_]  eq "");
	 if ($all_addr[$_] =~ /^(http|https):\/\/\S+\.\w{0,}$/) {  
	   domainCheck($all_addr[$_]);
	 } else {
	   my $out_format = sprintf "| %-50.50s %-10s  %-20s|\n", $all_addr[$_], "WRONG", "N/A";
	   printf OUT $out_format;
	   printf $out_format;
			 push @errors, "$all_addr[$_] is WRONG Address.";
	 }
	}
}

sub domainCheck {
    my $target = $_[0];
	my $ua = LWP::UserAgent->new;
	$ua->agent("$0/0.1 " . $ua->agent);
	my $req = HTTP::Request->new(GET => "$target");
	$req->header('Accept' => '*/*');
	my $startTime = time;
	my $res = $ua->request($req);
	storeServerStatus($res);
	if ($res->is_success) {
	  my $endTime = time;
	  my $out_format;
	  $endTime = ($endTime - $startTime);
	  if ($response_limit && ($response_limit <= $endTime)) {
		 push(@errors, "Slow response from $target\: $endTime seconds");
		 $out_format = sprintf "| %-50.50s %-10s %-20s |\n", $target, "SLOW", "Response $endTime seconds";
	  } else {
		 $out_format = sprintf "| %-50.50s %-10s %-20s |\n", 
			  $target, "ACCESSED", "Response $endTime seconds";
	  }
	  print OUT $out_format;
	  toss($out_format);
	} else {
	  my $out_format = sprintf "| %-50.50s %-10s %-20s |\n", $target, "DOWN", " N/A";
	  push(@errors, "$target is DOWN." . $res->status_line) or error("Cannot push error for DOWN");
	  print OUT $out_format;
	  toss($out_format);
    }
}

sub storeServerStatus() {
	push(@serverStatuses, $_[0]);
	toss("Added request");
}

sub toss() {
	my $what = $_[0];
	if($consolePrint == 1) {
		print $what;
	}
}

sub error {
  my $error_msg = shift;
  open ERR,">> $error_log" or die "Cannot open log file $error_log : $!\n";
  print ERR "$localtime\: $error_msg : $!\n";
  close ERR or die "Cannot close log file $error_log : $!\n";
}

sub cleanUp() {
	my $err = join "\015\012",@errors;
	my $err_num = scalar @errors;
	untie @all_addr or error("Unable to close file $domains");

	close OUT or error("Unable to close file $output_file");
	print "\nProcess FINISH\n";
}

sub printAllStatuses() {
	print '<div class="wrapper">';
	print '<table class="table"><thead><tr>URL<th>Status</th>Last modified<th></th><th>When Requested</th></tr></thead><tbody>';
	foreach(@serverStatuses) {
		print '<tr><td>' . $_->request()->uri() . '</td><td>' . $_->status_line() . '</td><td>' . $_->header("Last-Modified") . '</td><td>' . $_->header("Content-type") . '</td></tr>';
	}
	print '</tbody></table>';
	print '</div>';
}

sub printHead() {
	print "Content-type: text/html;charset=utf-8\n\n";
	print "<!DOCTYPE html>\n<html>\n<head><title>Domain statusoverview</title></head>\n<body>";
}

sub printTail() {
	print "<footer>&copy;vegaasen</footer>\n</body></html>\n";
}

# Start the thingie, plx!

checkAddresses();
cleanUp();
printHead();
printAllStatuses();
printTail();