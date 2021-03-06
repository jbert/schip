use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Schip',
    VERSION_FROM      => 'lib/Schip.pm', # finds $VERSION
    PREREQ_PM         => {
		'Class::ErrorHandler'	=> 0,
		'MooseX::NonMoose'		=> 0,
		},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Schip.pm', # retrieve abstract from module
       AUTHOR         => 'John Berthels <jjberthels@gmail.com>') : ()),
);
