#!/usr/bin/perl
# Parses #Warcraft in-game tweets from a CSV file for WoW item info.
# Author: Matthew Carras
# Date Created: 9-11-2016
# Last Update: 12-20-2016
# Note: Run makefile.bat to compile on Windows to an EXE using Perl and PAR::Packer.
# TODO: Add achievement /share parsing as well.
# TODO: Twitter API integration.
use strict;
use warnings;

use JSON::PP;
use Text::CSV;

use LWP::Simple;
use LWP::UserAgent;

# WoW Battle.net Dev Mashery API key is REQUIRED
my $mashery_apikey;
my $apikey_filename = 'mashery_apikey.txt';
my $default_filename = 'tweets.csv';

my $bnet_itemid_url = 'https://us.api.battle.net/wow/item/';

# Get the effective URL after all redirects using LWP::UserAgent
# Example: https://t.co/MolN74QY5l redirects to http://us.battle.net/wow/en/item/86568?wowLocale=0 and we need the latter URL so we can extract its item id
# Code from: http://stackoverflow.com/questions/2470053/how-can-i-get-the-ultimate-url-without-fetching-the-pages-using-perl-and-lwp#2470812
sub getEffectiveURL {
	my ($url) = @_;
	
	my $ua;  # Instance of LWP::UserAgent
	my $req; # Instance of (original) request
	my $res; # Instance of HTTP::Response returned via request method

	$ua = LWP::UserAgent->new;
	$ua->agent("$0/0.1 " . $ua->agent);

	$req = HTTP::Request->new(HEAD => $url);
	$req->header('Accept' => 'text/html');

	$res = $ua->request($req);

	if ($res->is_success) {
		# Using double method invocation, prob. want to do testing of
		# whether res is defined.
		# This is inline version of
		# my $finalrequest = $res->request(); 
		# print "Final URL = " . $finalrequest->url() . "\n";
		# print "Final URI = " . $res->request()->uri() . "\n";
		return $res->request()->uri();
	} else {
		# print "Error: " . $res->status_line . " for url $url\n";
		return $res->status_line;
	}
}

my $file;
my $line;
my $data;

# Get API key from file if not already defined
if ( !defined($mashery_apikey) ) {
	$file = $apikey_filename;
	open($data, '<', $file) or die "Could not open '$file' $! WoW Battle.net Mashery API key is REQUIRED.\n";
	$line = <$data>;
	chomp $line;
	$mashery_apikey = $line;
	close $data;
}

# Make sure API key is valid. API key will probably be longer than this but I'm not sure of its conventions.
if ( length($mashery_apikey) < 10 ) { 
	die "Invalid API key found in '$apikey_filename'. WoW Battle.net Mashery API key is REQUIRED.\n";
}

# Initialize Text::CSV for parsing Comma-Separated Value files
my $csv = Text::CSV->new({ sep_char => ',' });
# Allow filename to be 1st argument, otherwise $default_filename
$file = $ARGV[0] or $file = $default_filename;

open($data, '<', $file) or die "Could not open '$file' $!\n";
# Loop over and parse each line of data from file
while ($line = <$data>) {
	# "chomp" to remove newlines and other trailing characters
	chomp $line;
	# Parse the line using the Text::CSV object we made earlier
	if ( $csv->parse($line) ) {
		# Create an array of fields.
		# TODO: For now, we just have 1 field per line (kinda pointless).
		my @fields = $csv->fields();
		my $tweet = $fields[0];
		
		# Get each shortened URL in tweet, if they exist
		# Example Tweet: Check out this item I just got! [Inquisitor's Glowering Eye] https://t.co/MolN74QY5l #Warcraft
		# "https://t.co/MolN74QY5l" will be extracted in the above example.
		# If the tweet has multiple links it will parse each one individually.
		foreach ( ( $tweet =~ m/(https?:\/\/\S+)/g ) ) {
			# get effective URL (after any redirects)
			my $output = getEffectiveURL($_);
			# Parse URL and extract $itemid from it (the digits after /item/)
			# Example: http://us.battle.net/wow/en/item/86568?wowLocale=0
			# "86568" will be extracted in the above example.
			if ( $output =~ m/https?:\/\/\S+\/item\/(\d+)/g ) {
				my $itemid = $1;
				print "\nItem ID: $itemid\n";
				# Lookup item id through WoW Mashery Community API
				$output = get "$bnet_itemid_url$itemid?locale=en_US&apikey=$mashery_apikey";
				print "JSON: $output";
				# Decode JSON into a perl scalar of hashed references
				my $hashref = decode_json $output;
				print "\n\nJSON-parsed Name Field: ".$$hashref{'name'}."\n";
			}
		}
	}
}
close $data;

# -- Below is just example text for reference --

# -- Example WoW Mashery JSON Output for Item ID #86568 --
# {"id":86568,"description":"","name":"Mr. Smite's Brass Compass","icon":"inv_misc_cat_trinket10","stackable":1,"itemBind":1,"bonusStats":[],"itemSpells":[{"spellId":127207,"spell":{"id":127207,"name":"Memory of Mr. Smite","icon":"achievement_character_tauren_male","description":"Release the memories of a long-lost first mate.","castTime":"Instant"},"nCharges":0,"consumable":false,"categoryId":0,"trigger":"ON_USE"}],"buyPrice":0,"itemClass":15,"itemSubClass":4,"containerSlots":0,"inventoryType":0,"equippable":false,"itemLevel":1,"maxCount":1,"maxDurability":0,"minFactionId":0,"minReputation":0,"quality":3,"sellPrice":0,"requiredSkill":0,"requiredLevel":1,"requiredSkillRank":0,"itemSource":{"sourceId":50336,"sourceType":"CREATURE_DROP"},"baseArmor":0,"hasSockets":false,"isAuctionable":false,"armor":0,"displayInfoId":0,"nameDescription":"","nameDescriptionColor":"000000","upgradable":true,"heroicTooltip":false,"context":"","bonusLists":[],"availableContexts":[""],"bonusSummary":{"defaultBonusLists":[],"chanceBonusLists":[],"bonusChances":[]},"artifactId":0}

# -- Wowhead example URL outputted in XML for Item ID #86568 --
# http://www.wowhead.com/item=86568?xml
# <wowhead><item id="86568"><name>Mr. Smite's Brass Compass</name><level>1</level><quality id="3">Rare</quality><class id="15">Miscellaneous</class><subclass id="4">Other (Miscellaneous)</subclass><icon displayId="0">inv_misc_cat_trinket10</icon><inventorySlot id="0"/><htmlTooltip><table><tr><td><!--nstart--><b class="q3">Mr. Smite's Brass Compass</b><!--nend--><!--ndstart--><!--ndend--><span style="color: #ffd100" class="whtt-extra whtt-ilvl"><br />Item Level <!--ilvl-->1</span><br /><!--bo-->Binds when picked up<br />Unique<br /><span class="toycolor">Toy</span><!--ebstats--><!--egstats--></td></tr></table><table><tr><td><span class="q2">Use: <a href="http://www.wowhead.com/spell=127207" class="q2">Release the memories of a long-lost first mate.</a> (2 Hrs Cooldown)</span><br /><br /><span style="color: #FFD200">Drop: </span>Yorik Sharpeye<br /><span style="color: #FFD200">Zone: </span>Vale of Eternal Blossoms<div class="whtt-extra whtt-dropchance">Drop Chance: 10.15%</div></td></tr></table></htmlTooltip><json>"classs":15,"flags2":8192,"id":86568,"level":1,"name":"5Mr. Smite's Brass Compass","slot":0,"source":[2],"sourcemore":[{"n":"Yorik Sharpeye","t":1,"ti":50336,"z":5840}],"subclass":4</json><jsonEquip>"cooldown":7200000,"maxcount":1,"reqlevel":1</jsonEquip><link>http://www.wowhead.com/item=86568</link></item></wowhead>
