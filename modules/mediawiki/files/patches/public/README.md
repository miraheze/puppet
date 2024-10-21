Patches stored here are not automatically applied, be sure to add them to public.json, run puppet, then run deploy-mediawiki.

public.json entries should have the format of:
```json
{
    "file": "patchname.patch",
    // Determines if patch is located in public or private directory,
    "public": true, // OR false
    // Which mediawiki version to apply the patch to
    "versions": ["1.41", "1.42"], // OR ["all"]
    // Path relative to /srv/mediawiki-staging/$version to apply patch at
    "path": "extensions/MirahezeMagic",
    // Determines if deploy-mediawiki will fail or discard patch and continue if patch does not apply properly
    "failureStrategy": "abort" // OR "discard"
}
```
