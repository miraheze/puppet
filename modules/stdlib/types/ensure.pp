# Basic ensure validator
# made by the Wikimedia Foundation see https://github.com/wikimedia/puppet/blob/production/modules/wmflib/types/ensure.pp
# Modified to use Stdlib as name
type Stdlib::Ensure = Enum['present', 'absent']
