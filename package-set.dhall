let upstream =
    https://github.com/dfinity/vessel-package-set/releases/download/mo-0.7.6-20230120/package-set.dhall

let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let additions = [
  { name = "filesystem"
  , repo = "https://github.com/TFC-Motley/Filesystem-proto"
  , version = "v0.0.4-alpha"
  , dependencies = ["base-ext","filepaths"] : List Text
  },
  { name = "nonfungible"
  , repo = "https://github.com/TFC-Motley/Nonfungible"
  , version = "v0.0.2-alpha"
  , dependencies = ["base-ext","filepaths","stableRBT"] : List Text
  },
  { name = "hashmap"
  , repo = "https://github.com/ZhenyaUsenko/motoko-hash-map"
  , version = "v8.0.0"
  , dependencies = [] : List Text
  },
  { name = "filepaths"
  , repo = "https://github.com/TFC-Motley/Filepath"
  , version = "v0.1.2"
  , dependencies = [] : List Text 
  },
  { name = "scheduling"
  , repo = "https://github.com/TFC-Motley/Scheduling"
  , version = "v0.0.3-alpha"
  , dependencies = [] : List Text 
  },
  { name = "array"
  , repo = "https://github.com/aviate-labs/array.mo"
  , version = "v0.1.1"
  , dependencies = [ "base" ]
  },
  { name = "cap"
  , repo = "https://github.com/stephenandrews/cap-motoko-library"
  , version = "v1.0.4-alt"
  , dependencies = [] : List Text
  },
  { name = "base-ext"
  , repo = "https://github.com/TFC-Motley/motoko-base-extended"
  , version = "v0.0.8-alpha"
  , dependencies = [ "stableRBT", "stableBuffer" ] : List Text 
  },
  { name = "struct"
  , repo = "https://github.com/TFC-Motley/Structures"
  , version = "v0.0.2-alpha"
  , dependencies = [] : List Text
  },
  { name = "stableRBT"
  , repo = "https://github.com/canscale/StableRBTree"
  , version = "v0.6.0"
  , dependencies = [] : List Text
  },
  { name = "stableBuffer"
  , repo = "https://github.com/canscale/StableBuffer"
  , version = "v0.2.0"
  , dependencies = [] : List Text
  },
  { name = "base"
  , repo = "https://github.com/dfinity/motoko-base"
  , version = "moc-0.7.6"
  , dependencies = [] : List Text
  },
  { name = "base-0.7.3"
  , repo = "https://github.com/dfinity/motoko-base"
  , version = "aafcdee0c8328087aeed506e64aa2ff4ed329b47"
  , dependencies = [] : List Text
  },
  { name = "encoding"
  , repo = "https://github.com/aviate-labs/encoding.mo"
  , version = "v0.4.1"
  , dependencies = [] : List Text
  },
  { name = "crypto"
  , repo = "https://github.com/aviate-labs/crypto.mo"
  , version = "v0.3.1"
  , dependencies = [] : List Text
  },] : List Package

in  upstream # additions