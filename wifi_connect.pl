#!/usr/bin/perl
use strict;
use warnings;

my $dev = "wlp0s20u7"; 
#if (defined $ARGV[0]) {
#	$dev = $ARGV[0];
#}else {
#	die "Must enter device\n";
#}


my $choice = mainMenu();
if($choice == 1) {
	prevConn();
}elsif($choice == 2) {
	newConn();
}elsif($choice == 3) {
	resetConn();
}else{

}


#Simple Menu 
sub mainMenu {
	print "\n========================================================\n";
	print "Wifi Manager v5.0\n";
	print "[1] Use archived connection\n";
	print "[2] Scan for and connect to a new network\n";
	print "[3] Reset network connection\n";
	print "Your choice: ";
	my $choice = <STDIN>;
	print "\n";

	return $choice;
}

#Connect to a archived connection
sub prevConn {
	print "Now listing previously established connections...\n";
	my @pc = `ls /etc/wpa_supplicant`;
	my $len = scalar(@pc);
	chomp(@pc);

	my $count = 0;
	foreach my $elem (@pc) {
		$count++;
		print "[$count]$elem\n";
	}
	print "Your choice: ";
	my $choice = <STDIN>;
	$choice--;

	`wpa_supplicant -B -c /etc/wpa_supplicant/$pc[$choice] -i$dev -d`;
	`dhcpcd $dev`;
	`wget google.com 2>/dev/null`;
	`rm index.html`;
	print "\n...Fin\n\n";
}	

#Scan, display, and connect to a new network
sub newConn {
	my %hash;
	`ip link set $dev up`;
	my $netScan = `iwlist $dev scan`;

	#Splitting into unique network cells
	my @cells = split/Cell/,$netScan;
	shift(@cells);

	#Iterate through each cell individually
	my $len= scalar(@cells);
	for(my $i = 0; $i < $len; $i++) {
	my  @data = ("","","","","","","","","","");
	#Split cells by newline char and iterate
		my @lines = split(/\n/, $cells[$i]);
		foreach my $elem (@lines) {
			$elem =~ s/^\s+//;
			if(index($elem,'Address') != -1){
				$data[0] = "$elem\n";
				$data[1] = address($elem);
			}
			if(index($elem, 'Frequency') != -1) {
				$data[4] = "     $elem\n";
				$data[5] = " ";
			}
			if(index($elem, 'Quality') != -1) {
				$data[6] = "     $elem\n";
				$data[7] = quality($elem);
			}
			if(index($elem,'Encryption key') != -1) {
				$data[8] = "     $elem\n";
				$data[9] = encrypt($elem);
			}
			if(index($elem,'ESSID:') != -1) {
				$data[2] = "     $elem\n";
				$data[3] =  essid($elem);
			}
		}
		$hash{"Cell $i"} = \@data;	
	}
	
	for my $key ( sort {$hash{$b}[7] <=> $hash{$a}[7]} keys %hash) {
		print "$hash{$key}[0]";
		print "$hash{$key}[2]";
		print "$hash{$key}[4]";
		print "$hash{$key}[6]";
		print "$hash{$key}[8]";
		print "\n";
	}
	
	print "Please choose a connection:  ";
	my $in = <STDIN>;
	$in = $in - 1;

	my $id = $hash{"Cell $in"}[3];		#has spaces
	my $sid = spaceToScore($id);		#underscores		
	my $en = $hash{"Cell $in"}[9];		#on/off encrypt status
	my $bssid = $hash{"Cell $in"}[1]; 	#bssid

	if($en eq "off"){
		`touch /etc/wpa_supplicant/$sid.conf`;
		`printf "ctrl_interface=/var/run/wpa_supplicant\nnetwork={\n\tssid=\\"$id\\"\n\tbssid=$bssid\n\tproto=RSN\n\tkey_mgmt=NONE\n}" > /etc/wpa_supplicant/$sid.conf`;
		print "\n";

	}else{
		print "Please enter password: ";
		my $pass = <STDIN>;
		chomp($pass);

		while(length($pass) < 8 || length($pass) > 36){
			print "Pass must be between 8 and 36 characters\n";
			print "Please enter password: ";
			$pass = <STDIN>;
			chomp($pass);
		}
			
		`wpa_passphrase "$id" "$pass" > /etc/wpa_supplicant/$sid.conf`;
		
		#Edit new config file to include bssid and add quotes to id and pass
		my $file = `cat /etc/wpa_supplicant/$sid.conf`;
		my @lines = split(/\n/,$file);
		$lines[1] = "\n$lines[1]";
		substr($lines[1], 8, 0) = '\"';
		$lines[1] = "$lines[1]" . '\"';
		splice(@lines, 2, 0, "\n\tbssid=$bssid");
		$lines[3] = "\n$lines[3]";
		substr($lines[3], 8, 0) = '\"';
		$lines[3] = "$lines[3]" . '\"';
		$lines[4] = "\n$lines[4]";
		$lines[5] = "\n$lines[5]";
		my $join = join ("", @lines);

		`echo "$join" > /etc/wpa_supplicant/$sid.conf`;
		print "\n";
	}

	print "New config file located at /etc/wpa_supplicant/$sid.conf\n";
	print "Now connecting . . . . \n";

	`ip link set $dev up`;
	`wpa_supplicant -B -c /etc/wpa_supplicant/$sid.conf -i$dev -d`;
	`dhcpcd $dev`;
	`wget google.com 2>/dev/null`;
	`rm index.html`;
	print "\n...Fin\n\n";
}

#Resets network connection completely
sub resetConn {
	print "Closing current connection...\n\n";
	`dhcpcd $dev -k`;
	`ip link set $dev down`;
	`kill wpa_supplicant`;
}

#Parses out physical address
sub address {
	my ($str) = @_;
	$str = removeSpaces($str);
	my @addy = split(/:/,$str,2);
	return $addy[1];
}

#Parse out quality
sub quality { 
	my ($str) = @_;
	my @qual = split(/=/,$str,2);
	my @q = split(/\//,$qual[1],2);
	return $q[0];
}

#Parses out encryption key info
sub encrypt{
	my ($str) = @_;
	my @encrypt = split(/:/,$str,2);
	return $encrypt[1];
}

#Parses out essid info
sub essid {
	my ($str) = @_;
	$str = removeQuotes($str);
	my @id = split(/:/,$str,2);
	return $id[1];
}

#Removes all white spaces
sub removeSpaces {
	my ($str) = @_;
	$str =~ tr/ //ds;
	return $str;
}

#Removes quotes
sub removeQuotes {
	my ($str) = @_;
	$str =~ tr/"//ds;
	return $str;
}

#Replaces spaces with underscores
sub spaceToScore {
	my ($str) = @_;
	$str =~s/ /_/g;
	return $str;
}
