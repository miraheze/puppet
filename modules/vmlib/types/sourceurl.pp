# puppet file resource basic validator
type VMlib::Sourceurl = Variant[Undef, Pattern[/\Apuppet:\/\/\/modules\/.*/]]
