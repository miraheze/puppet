# puppet file resource basic validator
# copied from https://github.com/wikimedia/puppet/blob/production/modules/wmflib/types/sourceurl.pp
# but modified to be called Stdlib
type Stdlib::Sourceurl = Variant[Undef, Pattern[/\Apuppet:\/\/\/modules\/.*/]]
