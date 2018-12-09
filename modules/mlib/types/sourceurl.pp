# puppet file resource basic validator
type Mlib::Sourceurl = Variant[Undef, Pattern[/\Apuppet:\/\/\/modules\/.*/]]
