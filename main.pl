#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use JSON;
use Data::Dumper;


main();


sub main {

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

    inP10AndNotInSisyphus(\%sisyphusPackagesByArch, \%p10PackagesByArch);

    inSisyphusAndNotInP10(\%sisyphusPackagesByArch, \%p10PackagesByArch);

    versionSisyphusIsUpper(\%sisyphusPackagesByArch, \%p10PackagesByArch);

}


sub getAllPackages {

    my ($branch) = @_;

    my $baseUrl = "https://rdb.altlinux.org/api/export/branch_binary_packages/$branch";

    my $request = HTTP::Request->new(GET => $baseUrl);

    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($request);

    die "Ошибка запроса: ", $response->status_line unless $response->is_success;

    my $data = decode_json($response->content);

    return $data;

}


sub inP10AndNotInSisyphus {

    my %sisyphusPackagesByArch = %{shift()};
    my %p10PackagesByArch = %{shift()};

    foreach my $arch (keys %p10PackagesByArch) {

        for my $p10Package (@{$p10PackagesByArch{$arch}}) {

            my $found = 0;
            for my $sisyphusPackage (@{$sisyphusPackagesByArch{$arch}}) {
                if ($sisyphusPackage->{'name'} eq $p10Package->{'name'}) {
                    $found = 1;
                    last;
                }
            }

            if ($found) {
                print "Пакет $p10Package->{'name'} существует в Sisyphus\n";
            } else {
                print "Пакет $p10Package->{'name'} отсутствует в Sisyphus\n";
            }
        };

    }

}


sub inSisyphusAndNotInP10 {

    my %sisyphusPackagesByArch = %{shift()};
    my %p10PackagesByArch = %{shift()};

    foreach my $arch (keys %sisyphusPackagesByArch) {

        for my $sisyphusPackage (@{$sisyphusPackagesByArch{$arch}}) {

            my $found = 0;
            for my $p10Package (@{$p10PackagesByArch{$arch}}) {
                if ($p10Package->{'name'} eq $sisyphusPackage->{'name'}) {
                    $found = 1;
                    last;
                }
            }

            if ($found) {
                print "Пакет $sisyphusPackage->{'name'} существует в p10\n";
            } else {
                print "Пакет $sisyphusPackage->{'name'} отсутствует в p10\n";
            }
        };

    };

}


sub versionSisyphusIsUpper {

    my %sisyphusPackagesByArch = %{shift()};
    my %p10PackagesByArch = %{shift()};

    foreach my $arch (keys %sisyphusPackagesByArch) {

        for my $sisyphusPackage (@{$sisyphusPackagesByArch{$arch}}) {

            my $found = 0;
            for my $p10Package (@{$p10PackagesByArch{$arch}}) {
                if (compareVersions($sisyphusPackage->{'version'}, $p10Package->{'version'})) {
                    # Пакет подходит
                };
            }

        }

    }

}


sub compareVersions {

    my ($sisyphusPackageVersion, $p10PackageVersion) = @_;

    my @sisyphusPackageVersionParts = split(/\./, $sisyphusPackageVersion);
    my @p10PackageVersionParts = split(/\./, $p10PackageVersion);

    foreach my $index (0 .. $#sisyphusPackageVersionParts) {
        if ($sisyphusPackageVersionParts[$index] > $p10PackageVersionParts[$index]) {
            return 1;
        }
    }

}


sub createJson {

    my ($hash) = @_;

    my $json = JSON->new->utf8->pretty->encode($hash);

    my $file_name = 'output.json';
    open(my $fh, '>', $file_name) or die "Could not open file '$file_name' $!";
    print $fh $json;
    close($fh);

}



