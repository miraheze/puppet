# A strict type for the secrets like passwords or keys
type Icinga::Secret = Variant[String[1], Sensitive[String[1]]]
