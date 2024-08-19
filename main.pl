#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use JSON;


main();


sub main {

    print("Script was started\nPlease, wait\n");

    my $sisyphusPackages = getAllPackages('sisyphus');
    my $p10Packages = getAllPackages('p10');


    my %sisyphusPackagesByArch;

    foreach my $package (@{$sisyphusPackages->{packages}}) {

        my $packageInfo = {
            name    => $package->{name},
            version => $package->{version},
        };

        push @{$sisyphusPackagesByArch{$package->{arch}}}, $packageInfo;
    }


    my %p10PackagesByArch;

    foreach my $package (@{$p10Packages->{packages}}) {

        my $packageInfo = {
            name    => $package->{name},
            version => $package->{version},
        };

        push @{$p10PackagesByArch{$package->{arch}}}, $packageInfo;
    }

    my $inP10AndNotInSisyphusHash = inP10AndNotInSisyphus(\%sisyphusPackagesByArch, \%p10PackagesByArch);

    my $inSisyphusAndNotInP10Hash = inSisyphusAndNotInP10(\%sisyphusPackagesByArch, \%p10PackagesByArch);

    my $versionSisyphusIsUpperHash = versionSisyphusIsUpper(\%sisyphusPackagesByArch, \%p10PackagesByArch);

    my %resultHash = (
        inP10AndNotInSisyphus => $inP10AndNotInSisyphusHash->{'inP10AndNotInSisyphus'},
        inSisyphusAndNotInP10 => $inSisyphusAndNotInP10Hash->{'inSisyphusAndNotInP10'},
        versionSisyphusIsUpper => $versionSisyphusIsUpperHash->{'versionSisyphusIsUpper'},
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


sub inP10AndNotInSisyphus {

    my %sisyphusPackagesByArch = %{shift()};
    my %p10PackagesByArch = %{shift()};

    my %groupByAcrch;
    my %inP10AndNotInSisyphusHash;

    foreach my $arch (keys %p10PackagesByArch) {

        my @newPackageList;
        for my $p10Package (@{$p10PackagesByArch{$arch}}) {

            my $found = 0;
            for my $sisyphusPackage (@{$sisyphusPackagesByArch{$arch}}) {
                if ($sisyphusPackage->{'name'} eq $p10Package->{'name'}) {
                    $found = 1;
                    last;
                }
            }
            if (!($found)) {
                push @newPackageList, $p10Package;
            }

        };

        $groupByAcrch{$arch} = \@newPackageList;

    }

    $inP10AndNotInSisyphusHash{'inP10AndNotInSisyphus'} = \%groupByAcrch;

    return \%inP10AndNotInSisyphusHash;

}


sub inSisyphusAndNotInP10 {

    my %sisyphusPackagesByArch = %{shift()};
    my %p10PackagesByArch = %{shift()};

    my %groupByAcrch;
    my %inSisyphusAndNotInP10Hash;

    foreach my $arch (keys %sisyphusPackagesByArch) {

        my @newPackageList;
        for my $sisyphusPackage (@{$sisyphusPackagesByArch{$arch}}) {

            my $found = 0;
            for my $p10Package (@{$p10PackagesByArch{$arch}}) {
                if ($p10Package->{'name'} eq $sisyphusPackage->{'name'}) {
                    $found = 1;
                    last;
                }
            }

            if (!($found)) {
                push @newPackageList, $sisyphusPackage;
            }
        };

        $groupByAcrch{$arch} = \@newPackageList;

    };

    $inSisyphusAndNotInP10Hash{'inSisyphusAndNotInP10'} = \%groupByAcrch;

    return \%inSisyphusAndNotInP10Hash;

}


sub versionSisyphusIsUpper {

    my %sisyphusPackagesByArch = %{shift()};
    my %p10PackagesByArch = %{shift()};

    my %groupByAcrch;
    my %versionSisyphusIsUpperHash;

    foreach my $arch (keys %sisyphusPackagesByArch) {

        my @newPackageList;
        for my $sisyphusPackage (@{$sisyphusPackagesByArch{$arch}}) {

            my $found = 0;
            for my $p10Package (@{$p10PackagesByArch{$arch}}) {

                if ($sisyphusPackage->{'name'} eq $p10Package->{'name'}) {
                    if (compareVersions($sisyphusPackage->{'version'}, $p10Package->{'version'})) {
                        $found = 1;
                        last;
                    };
                }
            }

            if ($found) {
                push @newPackageList, $sisyphusPackage;
            }

        }

        $groupByAcrch{$arch} = \@newPackageList;

    }

    $versionSisyphusIsUpperHash{'versionSisyphusIsUpper'} = \%groupByAcrch;

    return \%versionSisyphusIsUpperHash;

}


sub compareVersions {

    my ($sisyphusPackageVersion, $p10PackageVersion) = @_;

    my @sisyphusPackageVersionParts = split(/\./, $sisyphusPackageVersion);
    my @p10PackageVersionParts = split(/\./, $p10PackageVersion);

    foreach my $index (0 .. $#sisyphusPackageVersionParts) {

        my $sisyphusPart = $sisyphusPackageVersionParts[$index];
        my $p10Part = $p10PackageVersionParts[$index];

        if (defined $p10Part && defined $sisyphusPart) {
            $sisyphusPart =~ s/[^0-9]+//g;
            $p10Part =~ s/[^0-9]+//g;

            if ($sisyphusPart gt $p10Part) {
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
