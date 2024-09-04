#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use JSON;


main();


sub main {

    print("Script was started\nPlease, wait\n");

    my $firstBranch = $ARGV[0];
    my $secondBranch = $ARGV[1];
    my $arch = $ARGV[2];

    my $firstBranchPackages = getAllPackages($firstBranch);
    my $secondBranchPackages = getAllPackages($secondBranch);


    my %firstBranchPackagesByArch;

    my $count = 0;
    foreach my $package (@{$firstBranchPackages->{packages}}) {

        if ($package->{arch} eq $arch) {
            my $packageInfo = {
                name    => $package->{name},
                version => $package->{version},
            };
            
            push @{$firstBranchPackagesByArch{$arch}}, $packageInfo;
            $count++;
        }

    }

    if ($count == 0) {
        print("No such arch '$arch' in '$firstBranch' branch!\n");
        return;
    }

    my %secondBranchPackagesByArch;

    $count = 0;
    foreach my $package (@{$secondBranchPackages->{packages}}) {

        if ($package->{arch} eq $arch) {
            my $packageInfo = {
                name    => $package->{name},
                version => $package->{version},
            };

            push @{$secondBranchPackagesByArch{$arch}}, $packageInfo;
            $count++;
        }
    }

    if ($count == 0) {
        print("No such arch '$arch' in '$secondBranch' branch!\n");
        return;
    }

    my $inSecondBranchAndNotInFirstBranchHash = inSecondBranchAndNotInFirstBranch(\%firstBranchPackagesByArch, \%secondBranchPackagesByArch, $arch, $firstBranch, $secondBranch);

    my $inFirstBranchAndNotInSecondBranchHash = inFirstBranchAndNotInSecondBranch(\%firstBranchPackagesByArch, \%secondBranchPackagesByArch, $arch, $firstBranch, $secondBranch);

    my $versionFirstBranchIsUpperHash = versionFirstBranchIsUpper(\%firstBranchPackagesByArch, \%secondBranchPackagesByArch, $arch, $firstBranch);

    my %resultHash = (
        "in" . $secondBranch . "AndNotIn" . $firstBranch => $inSecondBranchAndNotInFirstBranchHash->{"in" . $secondBranch . "AndNotIn" . $firstBranch},
        "in" . $firstBranch . "AndNotIn" . $secondBranch => $inFirstBranchAndNotInSecondBranchHash->{"in" . $firstBranch . "AndNotIn" . $secondBranch},
        "version" . $firstBranch . "IsUpper" => $versionFirstBranchIsUpperHash->{"version" . $firstBranch . "IsUpper"},
    );

    createJson(\%resultHash);

    print("Script is off\n");

}


sub getAllPackages {

    my ($branch) = @_;

    my $baseUrl = "https://rdb.altlinux.org/api/export/branch_binary_packages/$branch";

    my $request = HTTP::Request->new(GET => $baseUrl);

    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($request);

    die "Http error: ", $response->status_line unless $response->is_success;

    my $data = decode_json($response->content);

    return $data;

}


sub inSecondBranchAndNotInFirstBranch {

    my %firstBranchPackagesByArch = %{shift()};
    my %secondBranchPackagesByArch = %{shift()};
    my $arch = shift();
    my $firstBranch = shift();
    my $secondBranch = shift();

    my %inSecondBranchAndNotInFirstBranchHash;

    my @newPackageList;

    for my $secondBranchPackage (@{$secondBranchPackagesByArch{$arch}}) {

        my $found = 0;
        for my $firstBranchPackage (@{$firstBranchPackagesByArch{$arch}}) {
            if ($firstBranchPackage->{'name'} eq $secondBranchPackage->{'name'}) {
                $found = 1;
                last;
            }
        }
        if (!($found)) {
            push @newPackageList, $secondBranchPackage;
        }

    }

    $inSecondBranchAndNotInFirstBranchHash{"in" . $secondBranch . "AndNotIn" . $firstBranch} = \@newPackageList;

    return \%inSecondBranchAndNotInFirstBranchHash;

}


sub inFirstBranchAndNotInSecondBranch {

    my %firstBranchPackagesByArch = %{shift()};
    my %secondBranchPackagesByArch = %{shift()};
    my $arch = shift();
    my $firstBranch = shift();
    my $secondBranch = shift();

    my %inFirstBranchAndNotInSecondBranchHash;

    my @newPackageList;
    for my $firstBranchPackage (@{$firstBranchPackagesByArch{$arch}}) {

        my $found = 0;
        for my $secondBranchPackage (@{$secondBranchPackagesByArch{$arch}}) {
            if ($secondBranchPackage->{'name'} eq $firstBranchPackage->{'name'}) {
                $found = 1;
                last;
            }
        }

        if (!($found)) {
            push @newPackageList, $firstBranchPackage;
        }
    }

    $inFirstBranchAndNotInSecondBranchHash{"in" . $firstBranch . "AndNotIn" . $secondBranch} = \@newPackageList;

    return \%inFirstBranchAndNotInSecondBranchHash;

}


sub versionFirstBranchIsUpper {

    my %firstBranchPackagesByArch = %{shift()};
    my %secondBranchPackagesByArch = %{shift()};
    my $arch = shift();
    my $firstBranch = shift();

    my %versionFirstBranchIsUpperHash;

    my @newPackageList;
    for my $firstBranchPackage (@{$firstBranchPackagesByArch{$arch}}) {

        my $found = 0;
        for my $secondBranchPackage (@{$secondBranchPackagesByArch{$arch}}) {

            if ($firstBranchPackage->{'name'} eq $secondBranchPackage->{'name'}) {
                if (compareVersions($firstBranchPackage->{'version'}, $secondBranchPackage->{'version'})) {
                    $found = 1;
                    last;
                };
            }
        }

        if ($found) {
            push @newPackageList, $firstBranchPackage;
        }

    }

    $versionFirstBranchIsUpperHash{"version" . $firstBranch . "IsUpper"} = \@newPackageList;

    return \%versionFirstBranchIsUpperHash;

}


sub compareVersions {

    my ($firstBranchPackageVersion, $secondBranchPackageVersion) = @_;

    my @firstBranchPackageVersionParts = split(/\./, $firstBranchPackageVersion);
    my @secondBranchPackageVersionParts = split(/\./, $secondBranchPackageVersion);

    foreach my $index (0 .. $#firstBranchPackageVersionParts) {

        my $firstBranchPart = $firstBranchPackageVersionParts[$index];
        my $secondBranchPart = $secondBranchPackageVersionParts[$index];

        if (defined $secondBranchPart && defined $firstBranchPart) {
            $firstBranchPart =~ s/[^0-9]+//g;
            $secondBranchPart =~ s/[^0-9]+//g;

            if ($firstBranchPart gt $secondBranchPart) {
                return 1;
            }
        }
    }
}


sub createJson {

    my ($hash) = @_;

    my $json = JSON->new->utf8->pretty->encode($hash);

    my $fileName = 'output.json';
    open(my $fh, '>', $fileName) or die "Could not open file '$fileName' $!";
    print $fh $json;
    close($fh);

}
